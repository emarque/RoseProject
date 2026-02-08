using System.ComponentModel.DataAnnotations;

namespace RoseReceptionist.API.Models;

public class ConversationContext
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public string AvatarKey { get; set; } = string.Empty;

    [Required]
    public string AvatarName { get; set; } = string.Empty;

    [Required]
    public string Role { get; set; } = string.Empty;

    [Required]
    public string MessageText { get; set; } = string.Empty;

    [Required]
    public string Response { get; set; } = string.Empty;

    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    [Required]
    public Guid SessionId { get; set; }
}
