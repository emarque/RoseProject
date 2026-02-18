using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Services;

public class ActivityService
{
    private readonly RoseDbContext _context;
    private readonly ILogger<ActivityService> _logger;

    public ActivityService(RoseDbContext context, ILogger<ActivityService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Gets the most recent activity that Rose is currently doing or has recently completed
    /// </summary>
    public async Task<ActivityLog?> GetCurrentActivityAsync()
    {
        try
        {
            // Get the most recent activity (within the last 10 minutes to be considered "current")
            var tenMinutesAgo = DateTime.UtcNow.AddMinutes(-10);
            
            var currentActivity = await _context.ActivityLogs
                .Where(a => a.StartTime >= tenMinutesAgo)
                .OrderByDescending(a => a.StartTime)
                .FirstOrDefaultAsync();

            return currentActivity;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving current activity");
            return null;
        }
    }

    /// <summary>
    /// Gets recent activities from the last specified number of hours
    /// </summary>
    public async Task<List<ActivityLog>> GetRecentActivitiesAsync(int hours = 2)
    {
        try
        {
            var cutoffTime = DateTime.UtcNow.AddHours(-hours);
            
            var recentActivities = await _context.ActivityLogs
                .Where(a => a.StartTime >= cutoffTime)
                .OrderByDescending(a => a.StartTime)
                .Take(10) // Limit to 10 most recent activities
                .ToListAsync();

            return recentActivities;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving recent activities");
            return new List<ActivityLog>();
        }
    }

    /// <summary>
    /// Formats activity information for context in chatbot prompts
    /// </summary>
    public string FormatCurrentActivityForContext(ActivityLog? activity)
    {
        if (activity == null)
        {
            return "";
        }

        var activityDescription = GetActivityDescription(activity);
        return activityDescription;
    }

    /// <summary>
    /// Formats recent activities summary for context in chatbot prompts
    /// </summary>
    public string FormatRecentActivitiesForContext(List<ActivityLog> activities)
    {
        if (activities == null || activities.Count == 0)
        {
            return "";
        }

        var descriptions = activities
            .Take(5) // Only include top 5 for brevity
            .Select(a => GetActivityDescription(a))
            .Where(d => !string.IsNullOrEmpty(d));

        return string.Join(", ", descriptions);
    }

    private string GetActivityDescription(ActivityLog activity)
    {
        // Map activity types to natural language descriptions
        var description = activity.ActivityType.ToLower() switch
        {
            "transient" => $"moving to {activity.ActivityName}",
            "linger" => $"doing {activity.ActivityName}",
            "sit" => $"sitting at {activity.ActivityName}",
            _ => activity.ActivityName
        };

        return description;
    }
}
