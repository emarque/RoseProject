# Hierarchical Menu Navigation System

This document describes the hierarchical menu navigation feature that allows users to navigate multi-level menus through natural language conversation.

## Overview

The menu system enables conversational navigation through nested categories of items/services. Instead of flat lists, users can drill down through categories to find what they want.

## Example Flow

**User:** "I'd like a beverage"
**Rose:** "Sure! We have Coffee, Tea, Water and Hot Chocolate available."

**User:** "Coffee"
**Rose:** "Sure! We have Mocha, Espresso, Latte, Iced Coffee and Cappuccino available."

**User:** "Mocha"
**Rose:** "*smiles* Coming right up!" [triggers give action for Mocha]

## Menu Structure

The default menu structure is:

```
Beverages/
  ├── Coffee/
  │   ├── Mocha
  │   ├── Espresso
  │   ├── Latte
  │   ├── Iced Coffee
  │   └── Cappuccino
  ├── Tea/
  │   ├── Green Tea
  │   ├── Black Tea
  │   ├── Herbal Tea
  │   └── Chai Tea
  ├── Water/
  │   ├── Water
  │   └── Sparkling Water
  └── Hot Chocolate/
      ├── Hot Chocolate
      └── White Hot Chocolate

Snacks/
  ├── Cookies
  ├── Chips
  ├── Fruit Basket
  └── Muffins
```

## How It Works

### Session Tracking

The system tracks each user's position in the menu using their session ID:
- **Current Category**: Where the user is in the menu (e.g., "Beverages.Coffee")
- **Available Options**: What options are available at the current level
- **Timeout**: Menu context expires after 5 minutes of inactivity

### Navigation Logic

1. **Top-Level Match**: When user says "beverage" or "snack", system matches to top-level category
2. **Context-Based Match**: When user is in a menu, their message is matched against available options
3. **Subcategory Navigation**: If matched option is a subcategory, navigate deeper
4. **Final Item Selection**: If matched option is a leaf item, trigger action

### Special Commands

- **Cancel**: "back", "cancel", "nevermind" - exits menu navigation
- **No Match**: If message doesn't match any option, falls back to AI chat

## Architecture

### Models

**MenuStructure** - Root container for all categories
```csharp
public class MenuStructure
{
    public Dictionary<string, MenuCategory> Categories { get; set; }
}
```

**MenuCategory** - A category that can contain subcategories or items
```csharp
public class MenuCategory
{
    public string Name { get; set; }
    public List<string>? Items { get; set; }  // Leaf items
    public Dictionary<string, MenuCategory>? Subcategories { get; set; }  // Nested categories
}
```

**MenuContext** - Tracks user's position in menu
```csharp
public class MenuContext
{
    public string? CurrentCategory { get; set; }  // e.g., "Beverages.Coffee"
    public List<string>? AvailableOptions { get; set; }
    public DateTime LastMenuInteraction { get; set; }
    public int TimeoutMinutes { get; set; } = 5;
}
```

### MenuService

Singleton service that manages menu structure and navigation:

**Key Methods:**
- `NavigateMenu(string message, Guid sessionId)` - Process user input and return navigation result
- `GetMenuContext(Guid sessionId)` - Retrieve current menu context for session
- `UpdateMenuContext(Guid sessionId, MenuContext context)` - Update session menu state
- `ClearMenuContext(Guid sessionId)` - Remove menu context (on cancel or completion)

**Navigation Result Types:**
- `ShowOptions` - User navigated to a category, show available options
- `FinalItem` - User selected a leaf item, trigger action
- `Cancelled` - User cancelled menu navigation
- `NoMatch` - Message didn't match any menu option

### ChatController Integration

The ChatController checks menu navigation before falling back to AI:

```csharp
var menuResult = _menuService.NavigateMenu(request.Message, request.SessionId);

if (menuResult.Type == MenuNavigationResultType.ShowOptions)
{
    // Return menu options
}
else if (menuResult.Type == MenuNavigationResultType.FinalItem)
{
    // Trigger give action
}
else
{
    // Fall back to AI chat
}
```

## Configuration

### Default Structure

The system includes a default menu structure (shown above). This is used if no custom configuration is provided.

### Custom Configuration (Future)

Menu structure can be customized via `appsettings.json`:

```json
{
  "Menu": {
    "Structure": {
      "Categories": {
        "Beverages": {
          "Name": "Beverages",
          "Subcategories": {
            "Coffee": {
              "Name": "Coffee",
              "Items": ["Mocha", "Espresso", "Latte"]
            }
          }
        }
      }
    }
  }
}
```

## Benefits

### User Experience
- **Natural Conversation**: Navigate menus by saying "beverage", "coffee", "mocha"
- **Progressive Disclosure**: Show only relevant options at each level
- **Context Aware**: System remembers where you are in the menu
- **Easy Cancel**: Say "back" or "nevermind" to exit

### System Design
- **Extensible**: Easy to add new categories and items
- **Stateful**: Per-session tracking with automatic timeout
- **Flexible**: Falls back to AI for non-menu conversations
- **Type Safe**: Strongly typed models with validation

## Technical Details

### Session Management

Menu contexts are stored in a `ConcurrentDictionary<Guid, MenuContext>`:
- Thread-safe for concurrent access
- Keyed by session ID
- Automatically cleaned up on timeout or completion

### Matching Algorithm

1. Convert user message to lowercase
2. Check for special commands (back, cancel, nevermind)
3. If no context, try to match top-level categories
4. If context exists, match against available options
5. Determine if match is subcategory or leaf item
6. Update context or trigger action accordingly

### Timeout Handling

- Default timeout: 5 minutes
- Checked on every `GetMenuContext()` call
- Expired contexts are automatically removed
- User starts fresh after timeout

## Examples

### Example 1: Full Navigation

```
User: "I'd like a beverage"
System: Matches "Beverages" category
Response: "Sure! We have Coffee, Tea, Water and Hot Chocolate available."
Context: CurrentCategory = "Beverages", Options = ["Coffee", "Tea", "Water", "Hot Chocolate"]

User: "Coffee"
System: Matches "Coffee" subcategory in Beverages
Response: "Sure! We have Mocha, Espresso, Latte, Iced Coffee and Cappuccino available."
Context: CurrentCategory = "Beverages.Coffee", Options = ["Mocha", "Espresso", "Latte", "Iced Coffee", "Cappuccino"]

User: "Mocha"
System: Matches "Mocha" leaf item
Response: "*smiles* Coming right up!"
Action: [ACTION:type=give,item=Mocha]
Context: Cleared
```

### Example 2: Direct to Category

```
User: "I'd like a snack"
System: Matches "Snacks" category (which has no subcategories)
Response: "Sure! We have Cookies, Chips, Fruit Basket and Muffins available."
Context: CurrentCategory = "Snacks", Options = ["Cookies", "Chips", "Fruit Basket", "Muffins"]

User: "Cookies"
System: Matches "Cookies" leaf item
Response: "*smiles* Coming right up!"
Action: [ACTION:type=give,item=Cookies]
Context: Cleared
```

### Example 3: Cancellation

```
User: "I'd like a beverage"
Response: "Sure! We have Coffee, Tea, Water and Hot Chocolate available."

User: "Actually, nevermind"
System: Detects cancellation keyword
Response: "No problem! Let me know if you need anything else."
Context: Cleared
```

### Example 4: No Match (Falls Back to AI)

```
User: "What's the weather like?"
System: No menu match, not in menu context
Response: [AI-generated response about weather]
Context: None
```

## Future Enhancements

1. **Dynamic Menu Loading**: Load menu from database or external config
2. **Personalization**: Remember user preferences and frequently ordered items
3. **Search**: "Show me all drinks with caffeine"
4. **Quantity**: "Two mochas please"
5. **Modifications**: "Latte with extra shot"
6. **Favorites**: "My usual" or "What I had last time"
7. **Recommendations**: "What do you recommend?" based on past orders
8. **Menu Visibility**: LSL integration to show visual menu in-world

## Testing

Test the menu navigation with these scenarios:

1. **Full Navigation**: beverage → coffee → mocha
2. **Direct Category**: snack → cookies
3. **Cancellation**: beverage → coffee → nevermind
4. **Invalid Option**: beverage → pizza (no match)
5. **Timeout**: beverage → [wait 6 minutes] → coffee (starts fresh)
6. **Multiple Sessions**: Different users can navigate independently

## Related Files

- `Models/MenuModels.cs` - Menu data structures
- `Services/MenuService.cs` - Menu navigation logic
- `Controllers/ChatController.cs` - Integration with chat flow
- `Program.cs` - Service registration

## Summary

The hierarchical menu system provides a natural, conversational way to navigate multi-level menus. It tracks user state per session, handles timeouts gracefully, and falls back to AI for non-menu conversations. This creates a seamless experience where users can get specific items through guided navigation or ask questions naturally.
