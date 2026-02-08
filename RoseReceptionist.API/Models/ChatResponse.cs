namespace RoseReceptionist.API.Models;

public class ChatResponse
{
    public string Response { get; set; } = string.Empty;
    public bool ShouldNotifyOwners { get; set; }
    public string SuggestedAnimation { get; set; } = string.Empty;
}

public class ArrivalResponse
{
    public string Greeting { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public bool ShouldNotifyOwners { get; set; }
    public Guid SessionId { get; set; }
}

public class MessageQueueResponse
{
    public Guid MessageId { get; set; }
    public bool Queued { get; set; }
}

public class PendingMessagesResponse
{
    public List<MessageDto> Messages { get; set; } = new();
}

public class MessageDto
{
    public Guid Id { get; set; }
    public string FromAvatarName { get; set; } = string.Empty;
    public string MessageContent { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
