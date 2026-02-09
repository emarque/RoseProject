using Microsoft.AspNetCore.Mvc;
using RoseReceptionist.API.Models;
using RoseReceptionist.API.Services;

namespace RoseReceptionist.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReportsController : ControllerBase
{
    private readonly DailyReportService _reportService;
    private readonly ILogger<ReportsController> _logger;

    public ReportsController(
        DailyReportService reportService,
        ILogger<ReportsController> logger)
    {
        _reportService = reportService;
        _logger = logger;
    }

    [HttpPost("daily")]
    public async Task<ActionResult<DailyReport>> GenerateDailyReport([FromBody] DailyReportRequest request)
    {
        if (request.ShiftStart >= request.ShiftEnd)
        {
            return BadRequest("Shift start time must be before shift end time");
        }

        try
        {
            var report = await _reportService.GenerateDailyReportAsync(
                request.ReportDate,
                request.ShiftStart,
                request.ShiftEnd);

            return Ok(report);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating daily report");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPost("activities")]
    public async Task<ActionResult<ActivityLog>> LogActivity([FromBody] ActivityLogRequest request)
    {
        if (string.IsNullOrEmpty(request.ActivityName) || string.IsNullOrEmpty(request.ActivityType))
        {
            return BadRequest("Activity name and type are required");
        }

        try
        {
            var activity = await _reportService.LogActivityAsync(
                request.ActivityName,
                request.ActivityType,
                request.Location,
                request.Orientation,
                request.Animation,
                request.Attachments,
                request.StartTime);

            return Ok(activity);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error logging activity");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPut("activities/{activityId}/complete")]
    public async Task<ActionResult<ActivityLog>> CompleteActivity(Guid activityId, [FromBody] CompleteActivityRequest? request = null)
    {
        try
        {
            var activity = await _reportService.CompleteActivityAsync(
                activityId,
                request?.EndTime);

            if (activity == null)
            {
                return NotFound($"Activity with ID {activityId} not found");
            }

            return Ok(activity);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error completing activity {ActivityId}", activityId);
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("activities/current")]
    public async Task<ActionResult<ActivityLog>> GetCurrentActivity()
    {
        try
        {
            var activity = await _reportService.GetCurrentActivityAsync();
            
            if (activity == null)
            {
                return Ok(new { message = "No current activity" });
            }

            return Ok(activity);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting current activity");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpGet("activities/date/{date}")]
    public async Task<ActionResult<List<ActivityLog>>> GetActivitiesByDate(DateTime date)
    {
        try
        {
            var activities = await _reportService.GetActivitiesForDateAsync(date);
            return Ok(activities);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting activities for date {Date}", date);
            return StatusCode(500, "Internal server error");
        }
    }
}

public class DailyReportRequest
{
    public DateTime ReportDate { get; set; } = DateTime.UtcNow.Date;
    public DateTime ShiftStart { get; set; }
    public DateTime ShiftEnd { get; set; }
}

public class ActivityLogRequest
{
    public string ActivityName { get; set; } = string.Empty;
    public string ActivityType { get; set; } = string.Empty;
    public string? Location { get; set; }
    public int? Orientation { get; set; }
    public string? Animation { get; set; }
    public string? Attachments { get; set; }
    public DateTime? StartTime { get; set; }
}

public class CompleteActivityRequest
{
    public DateTime? EndTime { get; set; }
}
