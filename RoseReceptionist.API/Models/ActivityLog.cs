using System.ComponentModel.DataAnnotations;

namespace RoseReceptionist.API.Models;

public class ActivityLog
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public string ActivityName { get; set; } = string.Empty;

    [Required]
    public string ActivityType { get; set; } = string.Empty; // "transient", "linger", "sit"

    public string? Location { get; set; }

    public int? Orientation { get; set; }

    public string? Animation { get; set; }

    public string? Attachments { get; set; } // JSON string of attachments

    public DateTime StartTime { get; set; } = DateTime.UtcNow;

    public DateTime? EndTime { get; set; }

    public int? DurationSeconds { get; set; }

    public string? Notes { get; set; }
}
