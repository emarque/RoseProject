using RoseReceptionist.API.Models;
using System.Collections.Concurrent;
using System.Text.Json;

namespace RoseReceptionist.API.Services;

/// <summary>
/// Service to manage hierarchical menus and track user navigation state
/// </summary>
public class MenuService
{
    private readonly ILogger<MenuService> _logger;
    private MenuStructure _menuStructure = new();
    
    // Track menu context per session
    private readonly ConcurrentDictionary<Guid, MenuContext> _sessionMenuContexts = new();

    public MenuService(ILogger<MenuService> logger, IConfiguration configuration)
    {
        _logger = logger;
        LoadMenuStructure(configuration);
    }

    private void LoadMenuStructure(IConfiguration configuration)
    {
        // Load menu structure from configuration or use defaults
        var menuJson = configuration["Menu:Structure"];
        
        if (!string.IsNullOrEmpty(menuJson))
        {
            try
            {
                _menuStructure = JsonSerializer.Deserialize<MenuStructure>(menuJson) ?? new MenuStructure();
                _logger.LogInformation("Loaded menu structure from configuration");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load menu structure from configuration, using defaults");
                LoadDefaultMenuStructure();
            }
        }
        else
        {
            LoadDefaultMenuStructure();
        }
    }

    private void LoadDefaultMenuStructure()
    {
        // Default hierarchical menu structure
        _menuStructure = new MenuStructure
        {
            Categories = new Dictionary<string, MenuCategory>
            {
                ["Beverages"] = new MenuCategory
                {
                    Name = "Beverages",
                    Subcategories = new Dictionary<string, MenuCategory>
                    {
                        ["Coffee"] = new MenuCategory
                        {
                            Name = "Coffee",
                            Items = new List<string> { "Mocha", "Espresso", "Latte", "Iced Coffee", "Cappuccino" }
                        },
                        ["Tea"] = new MenuCategory
                        {
                            Name = "Tea",
                            Items = new List<string> { "Green Tea", "Black Tea", "Herbal Tea", "Chai Tea" }
                        },
                        ["Water"] = new MenuCategory
                        {
                            Name = "Water",
                            Items = new List<string> { "Water", "Sparkling Water" }
                        },
                        ["Hot Chocolate"] = new MenuCategory
                        {
                            Name = "Hot Chocolate",
                            Items = new List<string> { "Hot Chocolate", "White Hot Chocolate" }
                        }
                    }
                },
                ["Snacks"] = new MenuCategory
                {
                    Name = "Snacks",
                    Items = new List<string> { "Cookies", "Chips", "Fruit Basket", "Muffins" }
                }
            }
        };
        
        _logger.LogInformation("Loaded default menu structure");
    }

    public MenuContext? GetMenuContext(Guid sessionId)
    {
        if (_sessionMenuContexts.TryGetValue(sessionId, out var context))
        {
            if (!context.IsExpired())
            {
                return context;
            }
            // Remove expired context
            _sessionMenuContexts.TryRemove(sessionId, out _);
        }
        return null;
    }

    public void UpdateMenuContext(Guid sessionId, MenuContext context)
    {
        context.LastMenuInteraction = DateTime.UtcNow;
        _sessionMenuContexts[sessionId] = context;
    }

    public void ClearMenuContext(Guid sessionId)
    {
        _sessionMenuContexts.TryRemove(sessionId, out _);
    }

    /// <summary>
    /// Navigate menu based on user's message and return available options
    /// </summary>
    public MenuNavigationResult NavigateMenu(string message, Guid sessionId)
    {
        var messageLower = message.ToLower().Trim();
        var currentContext = GetMenuContext(sessionId);

        // Check if user wants to go back or cancel
        if (messageLower.Contains("back") || messageLower.Contains("cancel") || messageLower.Contains("nevermind"))
        {
            ClearMenuContext(sessionId);
            return new MenuNavigationResult
            {
                Type = MenuNavigationResultType.Cancelled,
                Message = "No problem! Let me know if you need anything else."
            };
        }

        // If no context, check if message matches a top-level category
        if (currentContext == null || currentContext.IsExpired())
        {
            var topCategory = FindTopLevelCategory(messageLower);
            if (topCategory != null)
            {
                return NavigateToCategory(topCategory, sessionId);
            }
            
            // No match found
            return new MenuNavigationResult
            {
                Type = MenuNavigationResultType.NoMatch
            };
        }

        // User is in a menu, try to match their message to available options
        if (currentContext.AvailableOptions != null)
        {
            var selectedOption = currentContext.AvailableOptions
                .FirstOrDefault(opt => messageLower.Contains(opt.ToLower()));

            if (selectedOption != null)
            {
                // Check if this is a final item or a subcategory
                var categoryPath = currentContext.CurrentCategory ?? "";
                var nextLevel = GetNextLevel(categoryPath, selectedOption);
                
                if (nextLevel != null)
                {
                    // Navigate deeper
                    return NavigateToCategory(nextLevel, sessionId, categoryPath + "." + selectedOption);
                }
                else
                {
                    // This is a final item - trigger action
                    ClearMenuContext(sessionId);
                    return new MenuNavigationResult
                    {
                        Type = MenuNavigationResultType.FinalItem,
                        SelectedItem = selectedOption,
                        Message = $"*smiles* Coming right up!"
                    };
                }
            }
        }

        // No match found
        return new MenuNavigationResult
        {
            Type = MenuNavigationResultType.NoMatch,
            AvailableOptions = currentContext.AvailableOptions
        };
    }

    private MenuCategory? FindTopLevelCategory(string message)
    {
        foreach (var category in _menuStructure.Categories)
        {
            if (message.Contains(category.Key.ToLower()))
            {
                return category.Value;
            }
        }
        return null;
    }

    private MenuCategory? GetNextLevel(string currentPath, string selectedOption)
    {
        var parts = string.IsNullOrEmpty(currentPath) 
            ? new string[] { } 
            : currentPath.Split('.');
        
        // Navigate to current position
        MenuCategory? current = null;
        foreach (var part in parts)
        {
            if (current == null)
            {
                _menuStructure.Categories.TryGetValue(part, out current);
            }
            else if (current.Subcategories != null)
            {
                current.Subcategories.TryGetValue(part, out current);
            }
        }

        // Try to find selected option as subcategory
        if (current?.Subcategories != null && current.Subcategories.TryGetValue(selectedOption, out var subcategory))
        {
            return subcategory;
        }

        return null;
    }

    private MenuNavigationResult NavigateToCategory(MenuCategory category, Guid sessionId, string? categoryPath = null)
    {
        var options = new List<string>();
        
        // Get subcategories or items
        if (category.Subcategories != null && category.Subcategories.Count > 0)
        {
            options.AddRange(category.Subcategories.Keys);
        }
        else if (category.Items != null && category.Items.Count > 0)
        {
            options.AddRange(category.Items);
        }

        // Update context
        var context = new MenuContext
        {
            CurrentCategory = categoryPath ?? category.Name,
            AvailableOptions = options
        };
        UpdateMenuContext(sessionId, context);

        // Build appropriate message based on number of options
        string message;
        if (options.Count == 0)
        {
            message = "I'm sorry, there are no options available in this category.";
        }
        else if (options.Count == 1)
        {
            message = $"Sure! We have {options[0]} available.";
        }
        else if (options.Count == 2)
        {
            message = $"Sure! We have {options[0]} and {options[1]} available.";
        }
        else
        {
            message = $"Sure! We have {string.Join(", ", options.Take(options.Count - 1))} and {options.Last()} available.";
        }

        return new MenuNavigationResult
        {
            Type = MenuNavigationResultType.ShowOptions,
            AvailableOptions = options,
            CategoryName = category.Name,
            Message = message
        };
    }

    public List<string> GetAllLeafItems()
    {
        var items = new List<string>();
        
        foreach (var category in _menuStructure.Categories.Values)
        {
            CollectLeafItems(category, items);
        }
        
        return items;
    }

    private void CollectLeafItems(MenuCategory category, List<string> items)
    {
        if (category.Items != null)
        {
            items.AddRange(category.Items);
        }
        
        if (category.Subcategories != null)
        {
            foreach (var subcategory in category.Subcategories.Values)
            {
                CollectLeafItems(subcategory, items);
            }
        }
    }
}

public enum MenuNavigationResultType
{
    NoMatch,
    ShowOptions,
    FinalItem,
    Cancelled
}

public class MenuNavigationResult
{
    public MenuNavigationResultType Type { get; set; }
    public string? CategoryName { get; set; }
    public List<string>? AvailableOptions { get; set; }
    public string? SelectedItem { get; set; }
    public string? Message { get; set; }
}
