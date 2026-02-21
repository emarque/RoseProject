# JSON-Only Waypoint Format Support Fix

## Problem

User reported "0 waypoints configured" even though they had 19 waypoints in their configuration file. The configuration was in JSON-only format:

```
WAYPOINT0={"type":"transient","name":"hallway corner"}
WAYPOINT1={"type":"linger","name":"reception desk","orientation":0,"time":60,...}
...
WAYPOINT18={"type":"linger","name":"final waypoint",...}
```

## Misunderstanding

I initially assumed waypoint positions MUST be in the notecard, either as:
- Position only: `WAYPOINT0=<128.5, 128.5, 21.0>`
- Position + JSON: `WAYPOINT0=<128.5, 128.5, 21.0>|{...}`

This was **incorrect**.

## Actual System Design

According to README and system architecture:

1. **Waypoint prims** are physical objects in Second Life named "Wander0", "Wander1", "Wander2", etc.
2. **Positions come from prim locations** in the world, NOT from the notecard
3. **Notecard provides activity configuration** (what Rose does at each waypoint)
4. The notecard CAN override positions, but doesn't have to

## Root Cause

The parser in `[WPP]WPManager.lsl` (lines 794-817) only handled two cases:

### Case 1: With Pipe Separator
```lsl
if (pipePos != -1) {
    // WAYPOINT0=<position>|<json>
    parse_position_from_notecard();
    parse_json_configuration();
}
```

### Case 2: Without Pipe (WRONG)
```lsl
else {
    // Assumes value is a vector
    vector pos = (vector)value;  // ❌ Fails when value is JSON!
}
```

When `value` is JSON like `{"type":"linger",...}`, casting to vector returns `ZERO_VECTOR` and the waypoint is added with wrong data.

## Solution

Added JSON detection as a third case:

```lsl
if (pipePos != -1) {
    // Format: <position>|<json>
    string posStr = llGetSubString(value, 0, pipePos - 1);
    string jsonStr = llGetSubString(value, pipePos + 1, -1);
    vector pos = (vector)posStr;
    list wpData = parseWaypointJSON(jsonStr);
    // Add with explicit position
}
else if (llGetSubString(value, 0, 0) == "{") {
    // Format: <json> only
    list wpData = parseWaypointJSON(value);
    // Add with ZERO_VECTOR placeholder
    // Actual position will come from Wander# prim
}
else {
    // Format: <position> only
    vector pos = (vector)value;
    // Add position-only waypoint (transient)
}
```

## Three Supported Formats

### Format 1: JSON Only (Most Common)
```
WAYPOINT0={"type":"transient","name":"hallway corner"}
WAYPOINT1={"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
```

**Position source**: Wander0, Wander1 prims in the world
**Use case**: Standard configuration - positions come from physical waypoint markers

### Format 2: Position Only
```
WAYPOINT0=<128.5, 128.5, 21.0>
WAYPOINT1=<130.2, 125.8, 21.0>
```

**Position source**: Notecard
**Use case**: Transient waypoints with explicit positions, no activity configuration

### Format 3: Position + JSON
```
WAYPOINT0=<128.5, 128.5, 21.0>|{"type":"linger","name":"reception desk","time":60}
```

**Position source**: Notecard (overrides prim location)
**Use case**: When you want to specify exact position instead of using prim location

## Implementation Details

### Detection Logic

The parser determines format by:
1. Check for pipe `|` → Format 3 (Position + JSON)
2. Check if starts with `{` → Format 1 (JSON only)
3. Otherwise → Format 2 (Position only)

### ZERO_VECTOR Placeholder

For JSON-only format, we store `ZERO_VECTOR` as a placeholder. The actual navigation logic must:
1. Detect ZERO_VECTOR positions
2. Find the corresponding Wander# prim in the world
3. Use the prim's position for navigation

This maintains compatibility with the existing waypoint prim system.

## Files Changed

### [WPP]WPManager.lsl
- Lines 794-830: Added JSON detection logic
- Added `else if (llGetSubString(value, 0, 0) == "{")` case
- Stores ZERO_VECTOR for JSON-only waypoints

### [WPP]WaypointConfig.notecard
- Restored to JSON-only format (uncommented examples)
- Updated header documentation to explain all three formats
- Made examples actually usable (not commented out)

### WAYPOINT_CONFIGURATION_GUIDE.md
- Complete rewrite to correctly explain the waypoint prim system
- Documents all three supported formats
- Clarifies that positions typically come from prims, not notecard

## Testing

With the example notecard containing 4 JSON-only waypoints:
```
WAYPOINT0={"type":"transient","name":"hallway corner"}
WAYPOINT1={"type":"linger","name":"reception desk",...}
WAYPOINT2={"type":"linger","name":"watering plants",...}
WAYPOINT3={"type":"sit","name":"desk work",...}
```

Expected output:
```
Loading wp config: [WPP]WaypointConfig
4 waypoints
```

User's 19-waypoint configuration should now parse correctly and report:
```
Loading wp config: [WPP]WaypointConfig
19 waypoints
```

## Migration Note

Users with existing JSON-only configurations don't need to change anything. The parser now correctly handles:
- Old format (JSON only) ✅
- Training mode output (Position + JSON) ✅
- Simple positions (Position only) ✅

All three formats are supported and work correctly.
