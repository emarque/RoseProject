using System.ComponentModel.DataAnnotations;

namespace RoseReceptionist.API.Models;

public class DailyReport
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public DateTime ReportDate { get; set; }

    public DateTime ShiftStart { get; set; }

    public DateTime ShiftEnd { get; set; }

    public int TotalActivities { get; set; }

    public string ActivitySummary { get; set; } = string.Empty; // JSON array of activity summaries

    public string GeneratedReport { get; set; } = string.Empty; // Claude-generated "eager employee" summary

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
