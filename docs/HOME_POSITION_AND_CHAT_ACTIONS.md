# Home Position and Chat Action System

This document describes the new features added to the Rose Receptionist system for home position wandering and chatbot-to-world action integration.

## Table of Contents
1. [Home Position System](#home-position-system)
2. [Chat Context Enhancement](#chat-context-enhancement)
3. [Chat Action System](#chat-action-system)
4. [Configuration](#configuration)
5. [Examples](#examples)

---

## Home Position System

The wander system now supports a "home" position where Rose spends most of her time before starting her activity loop.

### Features

- **Configurable Home Waypoint**: Specify which waypoint number serves as Rose's home position
- **Configurable Home Duration**: Set how many minutes Rose should spend at home before starting activities
- **Loop Management**: Rose automatically returns to home after completing each full loop through all waypoints

### How It Works

1. When the system starts, Rose navigates to her home waypoint (if configured)
2. She stays at the home position for the configured duration (e.g., sitting at her desk)
3. After the home duration expires, she begins her normal wandering loop
4. When she completes a full loop (returns to waypoint 0), she goes back home
5. The cycle repeats

### Configuration

Add these lines to your `RoseConfig` notecard:

```
# Home position configuration
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=15
```

- `HOME_WAYPOINT`: The waypoint number to use as home (default: -1, disabled)
- `HOME_DURATION_MINUTES`: Minutes to spend at home before starting activities (default: 0)

Set `HOME_WAYPOINT=-1` to disable the home position feature and use traditional continuous wandering.

---

## Chat Context Enhancement

The chatbot now receives contextual information about Rose's current state and available capabilities.

### New Context Information

1. **Current Activity**: What Rose is currently doing (e.g., "watering plants", "at reception desk")
2. **Available Actions**: List of items/services Rose can provide (e.g., coffee types, services)
3. **Relationship Context**: System prompts now explicitly mention if speaking with owner vs. visitor

### Benefits

- More natural conversations that reference Rose's current activity
- Rose can offer services she actually has available
- Better personalization based on the visitor's relationship with Rose

---

## Chat Action System

Rose can now perform in-world actions based on natural language requests in chat.

### Supported Action Types

1. **Give** - Give an item to the requester
   - Example: User says "I'd love a coffee" → Rose triggers a give action with Coffee item

2. **Navigate** - Move to a specific location
   - Example: User says "Could you show me to the meeting room?" → Rose navigates there

3. **Gesture** - Perform an animation or gesture
   - Example: User says "Wave goodbye" → Rose performs wave animation

### How It Works

#### Backend (C#)

1. **ChatRequest** includes new fields:
   - `CurrentActivity`: Rose's current activity from wander script
   - `AvailableActions`: List of items/services available

2. **ClaudeService** receives context and includes it in AI prompts:
   - Informs AI about current activity
   - Lists available items/services
   - Instructs AI to include action tags in responses

3. **ChatController** parses action tags from AI responses:
   - Extracts action instructions like `[ACTION:type=give,item=Coffee]`
   - Returns actions in ChatResponse

4. **ChatResponse** includes:
   - `Actions`: List of ChatAction objects with Type, Target, and Parameters

#### Frontend (LSL)

1. **RoseReceptionist_Main.lsl**:
   - Maintains `current_activity` from wander script
   - Stores `AVAILABLE_ACTIONS` list from RoseConfig
   - Sends context with every chat request
   - Parses actions from chat responses
   - Executes actions via link messages

2. **RoseReceptionist_GoWander3.lsl**:
   - Sends activity updates via `LINK_ACTIVITY_UPDATE`
   - Notifies Main script whenever Rose starts a new activity

### Action Format

Actions are embedded in the AI response using this format:
```
[ACTION:type=give,item=Coffee]
[ACTION:type=navigate,location=MeetingRoom]
[ACTION:type=gesture,name=wave]
```

The Main script automatically:
- Removes action tags from displayed text
- Parses action parameters
- Sends appropriate link messages to handler scripts

---

## Configuration

### RoseConfig Notecard

Add these new configuration options:

```
# Home Position
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=15

# Available menu items (comma-separated)
AVAILABLE_ACTIONS=Coffee, Tea, Water, Hot Chocolate, Espresso, Cappuccino, Latte
```

### Waypoint Configuration

The home waypoint should be configured like any other waypoint in `[WPP]WaypointConfig`:

```json
{"type":"linger","name":"at reception desk","orientation":0,"time":900}
```

- Use `"time":900` for 15 minutes at home (900 seconds)
- Or set duration to 0 and control timing with `HOME_DURATION_MINUTES` instead

---

## Examples

### Example 1: Coffee Service via Chat

**User**: "Rose, could I get a coffee?"

**Rose**: "*smiles warmly* Of course! I'd be happy to get you a coffee. [ACTION:type=give,item=Coffee]"

**Result**: 
- Rose says: "*smiles warmly* Of course! I'd be happy to get you a coffee."
- Action executed: GIVE:Coffee sent to handler scripts

### Example 2: Context-Aware Response

**Setup**: Rose is currently watering plants (from wander activity)

**User**: "What are you up to, Rose?"

**Rose**: "*looks up from watering the plants* Just tending to the office greenery! Keeps the place feeling fresh and welcoming. Is there something I can help you with?"

**Result**: Rose's response naturally incorporates her current activity

### Example 3: Home Position Behavior

**Configuration**:
```
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=10
```

**Behavior**:
1. Rose starts at Waypoint 0 (home/reception desk)
2. Stays there for 10 minutes
3. Begins wandering: Waypoint 1 → 2 → 3 → ... → N
4. When loop completes (back to 0), returns to home
5. Stays at home for 10 minutes again
6. Cycle repeats

### Example 4: Multiple Services

**Configuration**:
```
AVAILABLE_ACTIONS=Espresso, Latte, Cappuccino, Tea, Water, Snacks
```

**User**: "What drinks do you have?"

**Rose**: "*smiles* We have espresso, latte, cappuccino, tea, and water. Would you like something?"

**User**: "A latte sounds perfect"

**Rose**: "*nods cheerfully* Coming right up! [ACTION:type=give,item=Latte]"

---

## Technical Details

### Link Message Constants

New constants added to coordinate between scripts:

- `LINK_ACTIVITY_UPDATE = 2001`: Wander script → Main script with activity name
- `LINK_ACTION_EXECUTE = 2002`: Main script → Other scripts to execute actions

### API Changes

**ChatRequest.cs**:
- Added `CurrentActivity` (string, optional)
- Added `AvailableActions` (List<string>, optional)

**ChatResponse.cs**:
- Added `Actions` (List<ChatAction>, optional)
- Added `ChatAction` class with Type, Target, Parameters

**ClaudeService.cs**:
- Updated all system prompt methods to accept context parameters
- Added `BuildContextInfo()` helper method
- Added `GetActionInstructions()` helper method

**ChatController.cs**:
- Added `ParseActionsFromResponse()` method
- Added `ParseActionString()` helper method
- Modified `PostMessage()` to parse and return actions

### State Management

The Main script maintains:
- `current_activity`: String tracking Rose's current activity
- `AVAILABLE_ACTIONS`: List of available menu items/services

Updates to `current_activity` come from the wander script via `LINK_ACTIVITY_UPDATE` whenever Rose starts a new activity.

---

## Future Enhancements

Potential improvements for future versions:

1. **Dynamic Action Lists**: Generate available actions based on inventory
2. **Multi-Step Actions**: Chain multiple actions together (e.g., navigate then give)
3. **Conditional Actions**: Execute actions based on requester's role
4. **Action Confirmation**: Request confirmation before executing certain actions
5. **Action History**: Track which actions have been performed for whom
6. **Custom Action Handlers**: Allow custom scripts to register action types
7. **Voice Commands**: Integrate with voice recognition for action triggers

---

## Troubleshooting

### Home Position Not Working

- Check `HOME_WAYPOINT` is set in RoseConfig
- Verify the waypoint number exists in [WPP]WaypointConfig
- Ensure `HOME_DURATION_MINUTES` is greater than 0
- Check owner console for "HOME_WAYPOINT:" confirmation message

### Actions Not Executing

- Verify `AVAILABLE_ACTIONS` is set in RoseConfig
- Check Main script receives actions in http_response
- Look for "Action: Give [item]" messages in owner console
- Ensure action handler scripts are present and listening for LINK_ACTION_EXECUTE

### Context Not Appearing in Chat

- Verify wander script sends LINK_ACTIVITY_UPDATE messages
- Check Main script stores current_activity
- Confirm available actions are loaded from RoseConfig
- Review API logs for context fields in requests

### Build Errors

If C# code fails to build:
- Ensure .NET 8.0 SDK is installed
- Run `dotnet restore` before building
- Check for typos in new property names
- Verify JSON serialization attributes are correct

---

## Testing Checklist

- [ ] Home position: Rose starts at home waypoint
- [ ] Home duration: Rose stays at home for configured time
- [ ] Loop completion: Rose returns to home after completing loop
- [ ] Activity updates: Current activity sent to Main script
- [ ] Context in requests: Activity and actions included in API calls
- [ ] AI understands context: Responses reference current activity
- [ ] AI suggests actions: Action tags appear in responses
- [ ] Action parsing: Actions extracted from responses
- [ ] Action execution: Link messages sent to handlers
- [ ] Configuration loading: All new config options read from notecard
- [ ] Build success: C# project compiles without errors

---

## Related Documentation

- [WAYPOINT_REFACTOR_SUMMARY.md](../WAYPOINT_REFACTOR_SUMMARY.md) - Waypoint system overview
- [FEATURES.md](../FEATURES.md) - Complete feature list
- [API_REFERENCE.md](../API_REFERENCE.md) - API endpoint documentation
- [README.md](../README.md) - General setup and usage
