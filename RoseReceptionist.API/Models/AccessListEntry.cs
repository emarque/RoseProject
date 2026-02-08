using System.ComponentModel.DataAnnotations;

namespace RoseReceptionist.API.Models;

public class AccessListEntry
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public string AvatarKey { get; set; } = string.Empty;

    [Required]
    public string AvatarName { get; set; } = string.Empty;

    [Required]
    public Role Role { get; set; } = Role.Visitor;

    public string? PersonalityNotes { get; set; }

    public string? FavoriteDrink { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime LastSeen { get; set; } = DateTime.UtcNow;
}

public enum Role
{
    Owner,
    Visitor,
    Blocked
}
