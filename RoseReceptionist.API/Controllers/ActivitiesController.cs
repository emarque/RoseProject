using Microsoft.AspNetCore.Mvc;
using RoseReceptionist.API.Authorization;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;

namespace RoseReceptionist.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[RequireSubscriberKey]
public class ActivitiesController : ControllerBase
{
    private readonly RoseDbContext _context;
    private readonly ILogger<ActivitiesController> _logger;

    public ActivitiesController(RoseDbContext context, ILogger<ActivitiesController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpPost("batch")]
    public async Task<ActionResult> LogActivityBatch([FromBody] List<BatchActivityRequest> activities)
    {
        if (activities == null || activities.Count == 0)
        {
            return BadRequest(new { error = "Activities list is required" });
        }

        try
        {
            var activityLogs = new List<ActivityLog>();

            foreach (var activity in activities)
            {
                if (string.IsNullOrEmpty(activity.Name) || string.IsNullOrEmpty(activity.Type))
                {
                    _logger.LogWarning("Skipping invalid activity in batch: Name or Type is empty");
                    continue;
                }

                // Validate timestamp (should be within reasonable range)
                if (activity.Timestamp <= 0 || activity.Timestamp > DateTimeOffset.UtcNow.ToUnixTimeSeconds() + 3600)
                {
                    _logger.LogWarning("Skipping activity with invalid timestamp: {Name}, Timestamp: {Timestamp}", 
                        activity.Name, activity.Timestamp);
                    continue;
                }

                var activityLog = new ActivityLog
                {
                    Id = Guid.NewGuid(),
                    ActivityName = activity.Name,
                    ActivityType = activity.Type,
                    StartTime = DateTimeOffset.FromUnixTimeSeconds(activity.Timestamp).UtcDateTime,
                    DurationSeconds = activity.Duration,
                    Location = null,
                    Orientation = null,
                    Animation = null,
                    Attachments = null,
                    EndTime = null
                };

                activityLogs.Add(activityLog);
            }

            _context.ActivityLogs.AddRange(activityLogs);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Logged batch of {Count} activities", activityLogs.Count);

            return Ok(new { 
                message = "Activities logged successfully", 
                count = activityLogs.Count 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error logging activity batch");
            return StatusCode(500, new { error = "Internal server error" });
        }
    }
}

public class BatchActivityRequest
{
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public int Duration { get; set; }
    public long Timestamp { get; set; }
}
