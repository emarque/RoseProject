using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RoseReceptionist.API.Authorization;
using RoseReceptionist.API.Data;
using RoseReceptionist.API.Models;
using System.Security.Cryptography;
using System.Text;

namespace RoseReceptionist.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[RequireSystemKey]
public class SystemController : ControllerBase
{
    private readonly RoseDbContext _context;
    private readonly ILogger<SystemController> _logger;
    private readonly IConfiguration _configuration;

    public SystemController(RoseDbContext context, ILogger<SystemController> logger, IConfiguration configuration)
    {
        _context = context;
        _logger = logger;
        _configuration = configuration;
    }

    [HttpPost("subscribers/generate-key")]
    public async Task<ActionResult<GenerateKeyResponse>> GenerateKey([FromBody] GenerateKeyRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.SubscriberId) || string.IsNullOrWhiteSpace(request.SubscriberName))
        {
            return BadRequest(new { error = "SubscriberId and SubscriberName are required" });
        }

        if (request.SubscriptionLevel < 1 || request.SubscriptionLevel > 3)
        {
            return BadRequest(new { error = "SubscriptionLevel must be 1 (Basic), 2 (Pro), or 3 (Enterprise)" });
        }

        // Generate unique API key
        var apiKey = GenerateApiKey();

        // Get default credit limit if not provided
        var creditLimit = request.CreditLimit ?? GetDefaultCreditLimit(request.SubscriptionLevel);

        var subscriberKey = new SubscriberApiKey
        {
            Id = Guid.NewGuid(),
            ApiKey = apiKey,
            SubscriberId = request.SubscriberId,
            SubscriberName = request.SubscriberName,
            SubscriptionLevel = request.SubscriptionLevel,
            Notes = request.Notes,
            OrderNumber = request.OrderNumber,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = request.ExpiresAt,
            RequestCount = 0,
            CreditsUsed = 0,
            CreditLimit = creditLimit
        };

        _context.SubscriberApiKeys.Add(subscriberKey);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Generated new API key for subscriber: {SubscriberName} ({SubscriberId})", 
            request.SubscriberName, request.SubscriberId);

        return Ok(new GenerateKeyResponse
        {
            Id = subscriberKey.Id,
            ApiKey = subscriberKey.ApiKey,
            SubscriberId = subscriberKey.SubscriberId,
            SubscriberName = subscriberKey.SubscriberName,
            SubscriptionLevel = subscriberKey.SubscriptionLevel,
            CreatedAt = subscriberKey.CreatedAt,
            ExpiresAt = subscriberKey.ExpiresAt,
            CreditLimit = subscriberKey.CreditLimit
        });
    }

    [HttpPut("subscribers/{id}/status")]
    public async Task<ActionResult> UpdateStatus(Guid id, [FromBody] UpdateStatusRequest request)
    {
        var subscriber = await _context.SubscriberApiKeys.FindAsync(id);
        if (subscriber == null)
        {
            return NotFound(new { error = "Subscriber not found" });
        }

        subscriber.IsActive = request.IsActive;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Updated status for subscriber {SubscriberName}: IsActive={IsActive}", 
            subscriber.SubscriberName, subscriber.IsActive);

        return Ok(new { message = "Status updated successfully", isActive = subscriber.IsActive });
    }

    [HttpGet("subscribers")]
    public async Task<ActionResult<List<SubscriberResponse>>> GetAllSubscribers(
        [FromQuery] bool? activeOnly = null,
        [FromQuery] int? level = null)
    {
        var query = _context.SubscriberApiKeys.AsQueryable();

        if (activeOnly.HasValue && activeOnly.Value)
        {
            query = query.Where(s => s.IsActive);
        }

        if (level.HasValue)
        {
            query = query.Where(s => s.SubscriptionLevel == level.Value);
        }

        var subscribers = await query
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new SubscriberResponse
            {
                Id = s.Id,
                ApiKey = s.ApiKey,
                SubscriberId = s.SubscriberId,
                SubscriberName = s.SubscriberName,
                SubscriptionLevel = s.SubscriptionLevel,
                Notes = s.Notes,
                OrderNumber = s.OrderNumber,
                IsActive = s.IsActive,
                CreatedAt = s.CreatedAt,
                ExpiresAt = s.ExpiresAt,
                LastUsedAt = s.LastUsedAt,
                RequestCount = s.RequestCount,
                CreditsUsed = s.CreditsUsed,
                CreditLimit = s.CreditLimit
            })
            .ToListAsync();

        return Ok(subscribers);
    }

    [HttpGet("subscribers/{id}")]
    public async Task<ActionResult<SubscriberResponse>> GetSubscriber(Guid id)
    {
        var subscriber = await _context.SubscriberApiKeys.FindAsync(id);
        if (subscriber == null)
        {
            return NotFound(new { error = "Subscriber not found" });
        }

        return Ok(new SubscriberResponse
        {
            Id = subscriber.Id,
            ApiKey = subscriber.ApiKey,
            SubscriberId = subscriber.SubscriberId,
            SubscriberName = subscriber.SubscriberName,
            SubscriptionLevel = subscriber.SubscriptionLevel,
            Notes = subscriber.Notes,
            OrderNumber = subscriber.OrderNumber,
            IsActive = subscriber.IsActive,
            CreatedAt = subscriber.CreatedAt,
            ExpiresAt = subscriber.ExpiresAt,
            LastUsedAt = subscriber.LastUsedAt,
            RequestCount = subscriber.RequestCount,
            CreditsUsed = subscriber.CreditsUsed,
            CreditLimit = subscriber.CreditLimit
        });
    }

    [HttpPut("subscribers/{id}/credits")]
    public async Task<ActionResult> UpdateCredits(Guid id, [FromBody] UpdateCreditsRequest request)
    {
        var subscriber = await _context.SubscriberApiKeys.FindAsync(id);
        if (subscriber == null)
        {
            return NotFound(new { error = "Subscriber not found" });
        }

        subscriber.CreditLimit = request.CreditLimit;
        if (request.ResetUsage)
        {
            subscriber.CreditsUsed = 0;
        }

        await _context.SaveChangesAsync();

        _logger.LogInformation("Updated credits for subscriber {SubscriberName}: Limit={CreditLimit}, Reset={Reset}", 
            subscriber.SubscriberName, subscriber.CreditLimit, request.ResetUsage);

        return Ok(new 
        { 
            message = "Credits updated successfully", 
            creditLimit = subscriber.CreditLimit,
            creditsUsed = subscriber.CreditsUsed
        });
    }

    [HttpGet("status")]
    public async Task<ActionResult<SystemStatusResponse>> GetSystemStatus()
    {
        var subscribers = await _context.SubscriberApiKeys.ToListAsync();

        var status = new SystemStatusResponse
        {
            TotalSubscribers = subscribers.Count,
            ActiveSubscribers = subscribers.Count(s => s.IsActive),
            TotalRequests = subscribers.Sum(s => s.RequestCount),
            TotalCreditsUsed = subscribers.Sum(s => s.CreditsUsed),
            ServerTime = DateTime.UtcNow,
            SubscribersByLevel = subscribers
                .GroupBy(s => s.SubscriptionLevel)
                .ToDictionary(g => g.Key, g => g.Count())
        };

        return Ok(status);
    }

    [HttpGet("logs")]
    public async Task<ActionResult<List<LogEntry>>> GetRecentLogs(
        [FromQuery] int count = 50,
        [FromQuery] string? subscriberName = null)
    {
        // For now, return activity logs as a proxy for system logs
        // In a production system, you'd read from actual log files
        var logsQuery = _context.ActivityLogs
            .OrderByDescending(a => a.StartTime)
            .Take(count);

        var logs = await logsQuery
            .Select(a => new LogEntry
            {
                Timestamp = a.StartTime,
                Level = "Information",
                Message = $"Activity: {a.ActivityType} - {a.ActivityName}",
                SubscriberName = null
            })
            .ToListAsync();

        return Ok(logs);
    }

    private string GenerateApiKey()
    {
        // Generate a secure random API key
        var bytes = new byte[32];
        using (var rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(bytes);
        }
        return Convert.ToBase64String(bytes).Replace("+", "-").Replace("/", "_").TrimEnd('=');
    }

    private int GetDefaultCreditLimit(int subscriptionLevel)
    {
        var key = $"SubscriptionLevels:{subscriptionLevel}:CreditLimit";
        var configValue = _configuration[key];
        
        if (int.TryParse(configValue, out var limit))
        {
            return limit;
        }

        // Default values if not configured
        return subscriptionLevel switch
        {
            1 => 1000,    // Basic
            2 => 5000,    // Pro
            3 => 50000,   // Enterprise
            _ => 1000
        };
    }
}
