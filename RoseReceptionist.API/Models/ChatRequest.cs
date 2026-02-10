namespace RoseReceptionist.API.Models;

public class ChatRequest
{
    public string AvatarKey { get; set; } = string.Empty;
    public string AvatarName { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public Guid SessionId { get; set; }
    public string? Transcript { get; set; } = null;
}

public class ArrivalRequest
{
    public string AvatarKey { get; set; } = string.Empty;
    public string AvatarName { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
}

public class MessageQueueRequest
{
    public string FromAvatarKey { get; set; } = string.Empty;
    public string FromAvatarName { get; set; } = string.Empty;
    public string ToAvatarKey { get; set; } = string.Empty;
    public string MessageContent { get; set; } = string.Empty;
}
