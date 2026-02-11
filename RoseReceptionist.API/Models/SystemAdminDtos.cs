namespace RoseReceptionist.API.Models;

// Request/Response DTOs for System Admin API

public class GenerateKeyRequest
{
    public string SubscriberId { get; set; } = string.Empty;
    public string SubscriberName { get; set; } = string.Empty;
    public int SubscriptionLevel { get; set; } = 1;
    public string? Notes { get; set; }
    public string? OrderNumber { get; set; }
    public int? CreditLimit { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool ExemptFromRateLimits { get; set; } = false;
}

public class GenerateKeyResponse
{
    public Guid Id { get; set; }
    public string ApiKey { get; set; } = string.Empty;
    public string SubscriberId { get; set; } = string.Empty;
    public string SubscriberName { get; set; } = string.Empty;
    public int SubscriptionLevel { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public int CreditLimit { get; set; }
}

public class UpdateStatusRequest
{
    public bool IsActive { get; set; }
}

public class UpdateCreditsRequest
{
    public int CreditLimit { get; set; }
    public bool ResetUsage { get; set; }
}

public class SubscriberResponse
{
    public Guid Id { get; set; }
    public string ApiKey { get; set; } = string.Empty;
    public string SubscriberId { get; set; } = string.Empty;
    public string SubscriberName { get; set; } = string.Empty;
    public int SubscriptionLevel { get; set; }
    public string? Notes { get; set; }
    public string? OrderNumber { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public DateTime? LastUsedAt { get; set; }
    public int RequestCount { get; set; }
    public int CreditsUsed { get; set; }
    public int CreditLimit { get; set; }
    public bool ExemptFromRateLimits { get; set; }
}

public class SystemStatusResponse
{
    public int TotalSubscribers { get; set; }
    public int ActiveSubscribers { get; set; }
    public int TotalRequests { get; set; }
    public int TotalCreditsUsed { get; set; }
    public DateTime ServerTime { get; set; }
    public Dictionary<int, int> SubscribersByLevel { get; set; } = new();
}

public class LogEntry
{
    public DateTime Timestamp { get; set; }
    public string Level { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string? SubscriberName { get; set; }
}

public class ExemptionRequest
{
    public bool ExemptFromRateLimits { get; set; }
}
