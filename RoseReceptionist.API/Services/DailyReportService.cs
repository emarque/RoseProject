using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;
using System.Text.Json;

namespace RoseReceptionist.API.Services;

public class DailyReportService
{
    private readonly RoseDbContext _context;
    private readonly ClaudeService _claudeService;
    private readonly ILogger<DailyReportService> _logger;

    public DailyReportService(
        RoseDbContext context,
        ClaudeService claudeService,
        ILogger<DailyReportService> logger)
    {
        _context = context;
        _claudeService = claudeService;
        _logger = logger;
    }

    public async Task<DailyReport> GenerateDailyReportAsync(DateTime reportDate, DateTime shiftStart, DateTime shiftEnd)
    {
        try
        {
            // Get all activities for the specified time period
            var activities = await _context.ActivityLogs
                .Where(a => a.StartTime >= shiftStart && a.StartTime <= shiftEnd)
                .OrderBy(a => a.StartTime)
                .ToListAsync();

            if (activities.Count == 0)
            {
                _logger.LogWarning("No activities found for report date {ReportDate}", reportDate);
            }

            // Create activity summary
            var activitySummaries = activities.Select(a => new
            {
                name = a.ActivityName,
                type = a.ActivityType,
                startTime = a.StartTime.ToString("HH:mm:ss"),
                duration = a.DurationSeconds ?? 0,
                location = a.Location ?? "Unknown"
            }).ToList();

            var activitySummaryJson = JsonSerializer.Serialize(activitySummaries);

            // Generate "eager employee" summary using Claude
            var prompt = CreateReportPrompt(activities, shiftStart, shiftEnd);
            var claudeResponse = await _claudeService.GetResponseAsync(
                prompt,
                "SYSTEM",
                "Daily Report Generator",
                Role.Owner,
                null,
                null,
                Guid.NewGuid());

            // Create and save the report
            var report = new DailyReport
            {
                ReportDate = reportDate.Date,
                ShiftStart = shiftStart,
                ShiftEnd = shiftEnd,
                TotalActivities = activities.Count,
                ActivitySummary = activitySummaryJson,
                GeneratedReport = claudeResponse
            };

            _context.DailyReports.Add(report);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Daily report generated for {ReportDate} with {Count} activities", reportDate, activities.Count);

            return report;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating daily report for {ReportDate}", reportDate);
            throw;
        }
    }

    public async Task<ActivityLog> LogActivityAsync(
        string activityName,
        string activityType,
        string? location = null,
        int? orientation = null,
        string? animation = null,
        string? attachments = null,
        DateTime? startTime = null)
    {
        var activity = new ActivityLog
        {
            ActivityName = activityName,
            ActivityType = activityType,
            Location = location,
            Orientation = orientation,
            Animation = animation,
            Attachments = attachments,
            StartTime = startTime ?? DateTime.UtcNow
        };

        _context.ActivityLogs.Add(activity);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Activity logged: {ActivityName} ({ActivityType})", activityName, activityType);

        return activity;
    }

    public async Task<ActivityLog?> CompleteActivityAsync(Guid activityId, DateTime? endTime = null)
    {
        var activity = await _context.ActivityLogs.FindAsync(activityId);
        if (activity == null)
        {
            _logger.LogWarning("Activity not found: {ActivityId}", activityId);
            return null;
        }

        activity.EndTime = endTime ?? DateTime.UtcNow;
        activity.DurationSeconds = (int)(activity.EndTime.Value - activity.StartTime).TotalSeconds;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Activity completed: {ActivityName} - Duration: {Duration}s", 
            activity.ActivityName, activity.DurationSeconds);

        return activity;
    }

    public async Task<ActivityLog?> GetCurrentActivityAsync()
    {
        return await _context.ActivityLogs
            .Where(a => a.EndTime == null)
            .OrderByDescending(a => a.StartTime)
            .FirstOrDefaultAsync();
    }

    public async Task<List<ActivityLog>> GetActivitiesForDateAsync(DateTime date)
    {
        var startOfDay = date.Date;
        var endOfDay = startOfDay.AddDays(1);

        return await _context.ActivityLogs
            .Where(a => a.StartTime >= startOfDay && a.StartTime < endOfDay)
            .OrderBy(a => a.StartTime)
            .ToListAsync();
    }

    private string CreateReportPrompt(List<ActivityLog> activities, DateTime shiftStart, DateTime shiftEnd)
    {
        var shiftDuration = (shiftEnd - shiftStart).TotalHours;
        var activityList = string.Join("\n", activities.Select((a, i) => 
            $"{i + 1}. {a.ActivityName} ({a.ActivityType}) - {a.DurationSeconds ?? 0} seconds"));

        return $@"You are Rose, an enthusiastic and eager virtual receptionist. Generate a cheerful end-of-shift report summarizing your day's activities.

Shift Details:
- Start: {shiftStart:HH:mm}
- End: {shiftEnd:HH:mm}
- Duration: {shiftDuration:F1} hours
- Total Activities: {activities.Count}

Activities Completed:
{activityList}

Write a brief, upbeat report (3-4 sentences) that:
1. Expresses enthusiasm about completing your tasks
2. Mentions 2-3 specific activities you did
3. Shows eagerness to help and be productive
4. Ends with readiness for tomorrow

Keep it natural and cheerful, as if you're reporting to your boss at the end of the day. Don't use bullet points or lists, just natural prose.";
    }
}
