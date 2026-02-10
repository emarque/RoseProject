# Waypoint System Documentation

## Overview

The Rose Receptionist waypoint system enables automated navigation and activity management for your virtual receptionist. Rose can walk to designated waypoint prims in sequence, perform various actions, and log activities through the API.

**🎓 NEW: Interactive Training Wizard** - Configure waypoints easily using dialog menus! No more manual JSON editing.

## Table of Contents

- [Quick Start](#quick-start)
- [Training Wizard](#training-wizard)
- [Waypoint Configuration](#waypoint-configuration)
- [Waypoint Naming](#waypoint-naming)
- [Action Types](#action-types)
- [Configuration](#configuration)
- [Examples](#examples)
- [API Integration](#api-integration)
- [Troubleshooting](#troubleshooting)

## Quick Start

### New Recommended Setup (with Training Wizard)

1. **Place waypoint prims** in your scene with sequential names:
   - `Waypoint0`
   - `Waypoint1`
   - `Waypoint2`
   - etc.

2. **Touch Rose** and select "Training Mode" from the menu

3. **Follow the wizard** to configure each waypoint:
   - Select waypoint type (transient, linger, sit)
   - Choose duration if needed
   - Pick an animation
   - Set orientation
   - Select attachments (coming soon)

4. **Copy the output** from chat and paste into `[WPP]WaypointConfig` notecard

5. **Done!** Scripts will automatically reload when you save the notecard

### Legacy Setup (Manual Configuration)

You can still configure waypoints manually by editing the `[WPP]WaypointConfig` notecard or by adding JSON to prim descriptions (not recommended due to character limits).

## Training Wizard

### Authorization

**Training mode is restricted to authorized managers only.**

- Only users listed in the `OWNER_UUID` configuration or the object owner can access training mode
- Unauthorized users will receive a polite message explaining they need manager authorization
- The owner will be notified when unauthorized access is attempted

### Accessing Training Mode

**For authorized managers:**
1. Touch the Rose receptionist object
2. Select "Training Mode" from the menu
3. If existing waypoint configurations are found, choose:
   - **Replace All**: Start fresh, replace all existing waypoints (numbering from 0)
   - **Add New**: Keep existing waypoints, add new ones (numbering continues from last waypoint)
   - **Cancel**: Exit training mode
4. Follow the interactive prompts

The training wizard will:
- Check your authorization before proceeding
- Detect existing waypoint configurations
- Offer replace or append mode if configurations exist
- Scan for all `Waypoint[0-9]+` prims within 50 meters
- Guide you through configuring each waypoint
- Generate properly formatted JSON
- Output configuration lines to chat

### Replace vs. Add New Mode

**Replace All Mode:**
- Starts numbering from WAYPOINT0
- Intended to completely replace existing configuration
- Use when redesigning your entire waypoint route

**Add New Mode:**
- Starts numbering from WAYPOINT(N+1) where N is the last existing waypoint
- Keeps existing waypoint configurations
- Use when extending your existing route with new waypoints

### Training Wizard Flow

For each waypoint, you'll be prompted for:

1. **Type Selection**
   - Transient: Pass through without stopping
   - Linger: Stop and perform an activity
   - Sit: Sit down at this location

2. **Duration** (for linger/sit types)
   - 15s, 30s, 60s, 120s
   - Custom (coming soon)
   - Skip (uses default 30s)

3. **Animation**
   - Lists all animations in inventory
   - Select one or choose "None"

4. **Orientation**
   - North (90°)
   - East (0°)
   - South (270°)
   - West (180°)
   - None (no rotation)

5. **Attachments** (coming soon)
   - Select objects to attach during this activity

### After Training

1. Look for lines in chat like:
   ```
   WAYPOINT0={"type":"linger","name":"reception desk",...}
   WAYPOINT1={"type":"transient","name":"hallway"}
   ```

2. Copy these lines

3. Open the `[WPP]WaypointConfig` notecard in Rose's inventory

4. **If you used "Replace All" mode:**
   - Delete all existing WAYPOINT lines
   - Paste the new lines

5. **If you used "Add New" mode:**
   - Keep existing WAYPOINT lines
   - Paste the new lines at the end

6. Save the notecard - scripts will automatically reload!

## Waypoint Configuration

### Configuration Storage

Waypoint configurations are now stored in the `[WPP]WaypointConfig` notecard. This notecard:
- Has no character limits (unlike prim descriptions)
- Is easy to edit and backup
- Supports comments and formatting
- Auto-reloads when changed

### Notecard Format

```
# Rose Receptionist Waypoint Configuration
# Lines starting with # are comments

WAYPOINT0={"type":"linger","name":"reception desk","orientation":0,"time":60,"animation":"stand_friendly","attachments":[]}
WAYPOINT1={"type":"transient","name":"hallway corner"}
WAYPOINT2={"type":"linger","name":"watering plants","orientation":90,"time":45,"animation":"watering","attachments":[{"item":"Watering Can","point":"RightHand"}]}
```

### Legacy: Prim Description Configuration

For backward compatibility, Rose will still read from prim descriptions if no notecard configuration exists for a waypoint. However, this is **not recommended** due to the 127-character limit on prim descriptions.

## Waypoint Naming

### Standard Format

Waypoints follow the naming pattern: `<PREFIX><NUMBER>`

- **Default prefix**: `Waypoint`
- **Number**: Integer starting from 0
- **Case-insensitive**: `Waypoint0`, `waypoint0`, and `WAYPOINT0` are all valid

### Custom Prefix

You can customize the prefix in the `RoseConfig` notecard:

```
WAYPOINT_PREFIX=Checkpoint
```

This allows names like: `Checkpoint0`, `Checkpoint1`, etc.

### Valid Examples

- `Waypoint0`, `Waypoint1`, `Waypoint2`
- `Waypoint 0` (spaces are trimmed)
- `checkpoint0` (case-insensitive)
- `Station0`, `Station1` (with custom prefix)

## Action Types

Waypoints can have three different types of behaviors:

### 1. Transient

Rose passes through without stopping.

**Notecard format:**
```
WAYPOINT0={"type":"transient","name":"hallway corner"}
```

**Use cases:**
- Navigation waypoints
- Corridor checkpoints
- Path markers

### 2. Linger

Rose stops and performs an activity for a specified duration.

**Notecard format:**
```
WAYPOINT1={"type":"linger","name":"filing documents","orientation":90,"time":60,"animation":"filing","attachments":[{"item":"Folder","point":"LeftHand"}]}
```

**Parameters:**
- `name`: Activity description (logged to API)
- `orientation`: Direction to face in degrees (0-359)
  - 0° = East
  - 90° = North
  - 180° = West
  - 270° = South
- `time`: Duration in seconds
- `animation`: Animation name to play (optional)
- `attachments`: Items to attach (optional)

### 3. Sit

Rose attempts to sit at the waypoint location.

**Notecard format:**
```
WAYPOINT2={"type":"sit","name":"desk work","time":120,"animation":"typing"}
```

**Important:** The waypoint prim must have a sit target configured for sitting to work properly.

## Configuration

### RoseConfig Notecard

Create a notecard named `RoseConfig` in the prim's inventory:

```
# Waypoint Configuration
WAYPOINT_PREFIX=Waypoint

# API Configuration
API_ENDPOINT=https://rosercp.pantherplays.com/api
API_KEY=your-api-key-here

# Shift Times (HH:MM format)
SHIFT_START_TIME=09:00
SHIFT_END_TIME=17:00
DAILY_REPORT_TIME=17:05
```

### Character Parameters

The pathfinding character is created with these parameters:

```lsl
CHARACTER_TYPE: CHARACTER_TYPE_A
CHARACTER_MAX_SPEED: 2.0
CHARACTER_DESIRED_SPEED: 1.5
CHARACTER_DESIRED_TURN_SPEED: 1.8
CHARACTER_RADIUS: 0.5
CHARACTER_LENGTH: 1.0
CHARACTER_AVOIDANCE_MODE: AVOID_CHARACTERS | AVOID_DYNAMIC_OBSTACLES
```

### System Limits

- **Sensor Range**: 50 meters
- **Navigation Timeout**: 60 seconds per waypoint
- **Proximity Threshold**: 1.0 meters (Rose is considered "arrived" when within this distance)

## Examples

### Example 1: Simple Reception Desk Route

Add these lines to your `[WPP]WaypointConfig` notecard:

```
WAYPOINT0={"type":"linger","name":"greeting at entrance","orientation":0,"time":10,"animation":"","attachments":[]}
WAYPOINT1={"type":"linger","name":"greeting visitors","orientation":0,"time":30,"animation":"","attachments":[]}
WAYPOINT2={"type":"transient","name":"corridor"}
```

### Example 2: Office Tasks Route

Add these lines to your `[WPP]WaypointConfig` notecard:

```
WAYPOINT0={"type":"linger","name":"checking mail","orientation":270,"time":25,"animation":"sorting","attachments":[]}
WAYPOINT1={"type":"linger","name":"watering plants","orientation":180,"time":45,"animation":"watering","attachments":[{"item":"WateringCan","point":"RightHand"}]}
WAYPOINT2={"type":"linger","name":"filing documents","orientation":90,"time":60,"animation":"filing","attachments":[{"item":"Folder","point":"LeftHand"}]}
WAYPOINT3={"type":"sit","name":"desk work","time":120,"animation":"typing"}
```

### Example 3: Using Training Wizard

1. Place 3 waypoint prims: Waypoint0, Waypoint1, Waypoint2
2. Touch Rose and select "Training Mode"
3. Follow the prompts:
   - Waypoint0: Type=Linger, Duration=30s, Animation=wave, Orientation=East
   - Waypoint1: Type=Transient
   - Waypoint2: Type=Linger, Duration=60s, Animation=idle, Orientation=North
4. Copy the output from chat
5. Paste into `[WPP]WaypointConfig` notecard
6. Save - done!

## API Integration

### Activity Logging

When Rose reaches a waypoint with a linger or sit action, the activity is automatically logged to the API:

**Endpoint:** `POST /api/reports/activities`

**Request:**
```json
{
  "activityName": "watering plants",
  "activityType": "linger",
  "location": "Waypoint1",
  "orientation": 180,
  "animation": "watering",
  "attachments": "[{\"item\":\"Can\",\"point\":\"RightHand\"}]"
}
```

**Response:**
```json
{
  "id": "activity-uuid",
  "startTime": "2026-02-10T14:30:00Z",
  "status": "in_progress"
}
```

### Activity Completion

When Rose moves to the next waypoint, the previous activity is marked complete:

**Endpoint:** `PUT /api/reports/activities/{id}/complete`

### Daily Reports

At the configured time (default 17:05), Rose generates a daily report:

**Endpoint:** `POST /api/reports/daily`

**Request:**
```json
{
  "reportDate": "2026-02-10T00:00:00Z",
  "shiftStart": "2026-02-10T09:00:00Z",
  "shiftEnd": "2026-02-10T17:00:00Z"
}
```

## Troubleshooting

### Rose isn't finding waypoints

**Check:**
1. Waypoints are named correctly: `<PREFIX><NUMBER>`
2. Waypoints are within 50 meters sensor range
3. Waypoint prefix matches your configuration
4. Numbers start from 0

**Debug:** Check the chat log for sensor results:
- "✓ Found: Waypoint0 (#0)" - Good
- "No Waypoint waypoints found" - Bad (check naming/range)

### Rose stops at a waypoint but doesn't continue

**Check:**
1. The waypoint description is valid (either a number or valid JSON)
2. For linger actions, ensure time is greater than 0
3. Check chat for parsing errors

### Rose skips waypoints

**Verify:**
1. All waypoints have sequential numbers (0, 1, 2, 3...)
2. No gaps in the sequence
3. Each waypoint is a separate prim (not part of a linkset)

### Rose walks but never reaches waypoint

**Check:**
1. Waypoint is on the navmesh
2. No obstacles blocking the path
3. Navigation timeout (60s) isn't being exceeded
4. Character settings are appropriate for your environment

### Activities not logging to API

**Verify:**
1. API_ENDPOINT is correct in RoseConfig
2. API_KEY is valid
3. Check HTTP errors in chat
4. API server is accessible

### Animations not playing

**Ensure:**
1. Animation names match animations in inventory
2. Animation script (RoseReceptionist_Animations.lsl) is present
3. Animations have proper permissions

## Advanced Topics

### Waypoint Scanning

- Scans occur on script startup
- Uses llSensor with 50m range and 180° arc
- Rescans if no waypoints found (30s interval)
- Rescans when chat interaction ends

### Navigation Behavior

- Uses llNavigateTo for pathfinding
- Checks arrival every 1 second (timer)
- Considers arrived when within 1.0 meter
- Times out after 60 seconds
- Stops navigation during chat interactions

### State Machine

Rose operates in these states:
- `IDLE`: Waiting to start or rescan
- `WALKING`: Navigating to next waypoint
- `LINGERING`: Performing timed activity
- `SITTING`: Sitting at waypoint
- `INTERACTING`: Paused for visitor interaction

### Link Messages

Rose responds to these link messages:
- `LINK_WANDERING_STATE` (2000): Control navigation state
  - "GREETING" or "CHATTING": Pause navigation
  - "IDLE" or "RESUME": Resume navigation
- `TOGGLE_WANDER`: Enable/disable wandering
- `WHAT_DOING`: Request current activity info

## Best Practices

1. **Start simple**: Use numeric descriptions first, add JSON details later
2. **Test navigation**: Place waypoints on the navmesh
3. **Use transient wisely**: For navigation-only waypoints
4. **Be consistent**: Use clear, descriptive activity names
5. **Plan your route**: Consider the physical space and navigation paths
6. **Monitor logs**: Watch chat for errors and debug info
7. **Update incrementally**: Test after adding each waypoint
8. **Document activities**: Use descriptive names for better reports

## Version History

- **v3.0**: Added simple numeric format support
- **v3.0**: Added CHARACTER_DESIRED_TURN_SPEED parameter
- **v2.0**: JSON-based waypoint system
- **v1.0**: Initial prim-based navigation

## Support

For issues or questions:
1. Check this documentation
2. Review the chat logs for error messages
3. Verify your configuration
4. Test with a minimal setup (2-3 waypoints)
5. Consult the project repository: [RoseProject](https://github.com/emarque/RoseProject)
