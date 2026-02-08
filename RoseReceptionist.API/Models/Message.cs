using System.ComponentModel.DataAnnotations;

namespace RoseReceptionist.API.Models;

public class Message
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public string FromAvatarKey { get; set; } = string.Empty;

    [Required]
    public string FromAvatarName { get; set; } = string.Empty;

    [Required]
    public string ToAvatarKey { get; set; } = string.Empty;

    [Required]
    public string MessageContent { get; set; } = string.Empty;

    public bool IsDelivered { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? DeliveredAt { get; set; }
}
