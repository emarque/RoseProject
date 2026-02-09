namespace RoseReceptionist.API.Models;

public class SubscriberApiKey
{
    public Guid Id { get; set; }
    public string ApiKey { get; set; } = string.Empty;
    public string SubscriberId { get; set; } = string.Empty;
    public string SubscriberName { get; set; } = string.Empty;
    public int SubscriptionLevel { get; set; } // 1=Basic, 2=Pro, 3=Enterprise
    public string? Notes { get; set; }
    public string? OrderNumber { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public DateTime? LastUsedAt { get; set; }
    public int RequestCount { get; set; }
    public int CreditsUsed { get; set; }
    public int CreditLimit { get; set; }
}

public enum SubscriptionLevel
{
    Basic = 1,
    Pro = 2,
    Enterprise = 3
}
