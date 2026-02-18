namespace RoseReceptionist.API.Models;

/// <summary>
/// Represents a hierarchical menu structure with categories and items
/// </summary>
public class MenuStructure
{
    public Dictionary<string, MenuCategory> Categories { get; set; } = new();
}

/// <summary>
/// Represents a menu category that can contain subcategories or items
/// </summary>
public class MenuCategory
{
    public string Name { get; set; } = string.Empty;
    public List<string>? Items { get; set; }  // Leaf items (e.g., "Mocha", "Latte")
    public Dictionary<string, MenuCategory>? Subcategories { get; set; }  // Nested categories (e.g., "Coffee" -> types)
}

/// <summary>
/// Tracks the user's current position in menu navigation
/// </summary>
public class MenuContext
{
    public string? CurrentCategory { get; set; }  // e.g., "Beverages" or "Beverages.Coffee"
    public List<string>? AvailableOptions { get; set; }  // Current options at this level
    public DateTime LastMenuInteraction { get; set; } = DateTime.UtcNow;
    public int TimeoutMinutes { get; set; } = 5;  // Reset menu context after 5 minutes
    
    public bool IsExpired()
    {
        return DateTime.UtcNow > LastMenuInteraction.AddMinutes(TimeoutMinutes);
    }
}
