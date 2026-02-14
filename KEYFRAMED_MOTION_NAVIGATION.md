# Keyframed Motion Navigation System

## Overview

The Rose Receptionist navigation system uses **llSetKeyframedMotion** instead of traditional pathfinding. This provides simpler, more reliable movement without requiring navmesh configuration.

## Key Features

### 1. Keyframed Motion
- **Linear movement** between waypoints
- **No navmesh required** - works anywhere
- **Predictable behavior** - smooth, direct paths
- **Configurable speed** - adjustable via RoseConfig

### 2. Door Blocking Detection
- **Automatic obstacle detection** using ray casting
- **Door recognition** via name pattern matching
- **Smart waypoint skipping** - automatically finds unblocked waypoint
- **Configurable** - can be disabled or customized

## Configuration

### RoseConfig Settings

```
# Navigation Configuration
MOVEMENT_SPEED=0.5

# Door Blocking Detection
DOOR_DETECTION_ENABLED=TRUE
DOOR_NAME_PATTERN=door
```

### Parameters

| Setting | Default | Description |
|---------|---------|-------------|
| `MOVEMENT_SPEED` | 0.5 | Movement speed in meters per second |
| `DOOR_DETECTION_ENABLED` | TRUE | Enable/disable door blocking detection |
| `DOOR_NAME_PATTERN` | door | Pattern for identifying doors (case-insensitive) |

## How It Works

### Navigation Flow

1. **Select Waypoint**
   - System cycles through waypoints sequentially
   - Checks if waypoint is blocked by door

2. **Door Detection**
   - Uses `llCastRay` to detect objects between current position and waypoint
   - Checks object names for door pattern
   - If door found, considers waypoint blocked

3. **Movement**
   - Calculates distance and travel time
   - Uses `llSetKeyframedMotion` for smooth linear movement
   - Plays walk animation during movement

4. **Arrival**
   - Timer checks distance to target every second
   - When within 1.0m tolerance, stops movement
   - Processes waypoint activity (sit, linger, etc.)

### Blocked Waypoint Handling

If a waypoint is blocked:
1. System automatically tries next waypoint
2. Continues cycling until unblocked waypoint found
3. If all waypoints blocked, waits 30 seconds and retries

## Door Detection System

### How Doors Are Detected

**Ray Casting:**
- Casts ray from current position to target waypoint
- Detects all objects in path
- Filters out agents and land

**Pattern Matching:**
- Checks each detected object's name
- Case-insensitive partial match
- Example: "door", "Door", "MainDoor", "doorway" all match

**Blocking Logic:**
- If any door-pattern object found in path, waypoint is blocked
- System skips to next waypoint automatically

### Door Naming Convention

For objects to be detected as doors, include the configured pattern in their name:

**Examples:**
```
"Main Door"
"door_office"
"Security Door"
"Doorway"
```

**Not detected:**
```
"Entrance" (no "door" in name)
"Wall" (no "door" in name)
```

### Customizing Door Pattern

Change the pattern in RoseConfig:
```
DOOR_NAME_PATTERN=gate
```

This will detect:
- "Main Gate"
- "Security gate"
- "Gateway"
- etc.

## Movement Mechanics

### Keyframed Motion Parameters

**Calculation:**
```lsl
vector offset = target_pos - current_pos;
float distance = llVecMag(offset);
float time_to_travel = distance / MOVEMENT_SPEED;

llSetKeyframedMotion([
    offset,           // Relative position offset
    ZERO_ROTATION,    // No rotation change
    time_to_travel    // Duration in seconds
], [KFM_DATA, KFM_TRANSLATION, KFM_MODE, KFM_FORWARD]);
```

**Features:**
- Linear interpolation between positions
- Smooth, constant-speed movement
- Automatic timing based on distance

### Speed Configuration

**Slower movement (more realistic):**
```
MOVEMENT_SPEED=0.3
```

**Faster movement:**
```
MOVEMENT_SPEED=1.0
```

**Recommended range:** 0.3 - 1.0 m/s

## Advantages Over Pathfinding

### Simplicity
- ❌ No navmesh baking required
- ❌ No pathfinding character setup
- ❌ No navigation failure handling
- ✅ Simple linear movement
- ✅ Works immediately

### Reliability
- ❌ No "unreachable" errors
- ❌ No "invalid start/goal" failures
- ❌ No navmesh gaps
- ✅ Always works (within physics limits)
- ✅ Predictable behavior

### Flexibility
- ✅ Works on any parcel
- ✅ No parcel permission requirements
- ✅ No region configuration needed
- ✅ Configurable obstacle detection

## Limitations

### Physical Obstacles
- **Cannot avoid solid objects** - uses linear path
- **May collide with prims** if they're in direct path
- **Solution:** Place waypoints to avoid obstacles

### Movement Path
- **Straight lines only** - no curved paths
- **No terrain following** - moves in 3D straight line
- **Solution:** Add intermediate waypoints for complex paths

### Door Detection
- **Name-based only** - relies on naming convention
- **No rotation check** - doesn't detect open/closed state
- **Solution:** Use consistent naming; position waypoints strategically

## Best Practices

### 1. Waypoint Placement
- Place waypoints in open, clear areas
- Avoid tight spaces or near obstacles
- Use intermediate waypoints for long distances
- Test each waypoint for accessibility

### 2. Door Setup
- Name doors consistently with pattern
- Position doors to clearly block paths
- Consider using multiple waypoints per room
- Test door detection with DEBUG_MODE

### 3. Speed Tuning
- Start with default 0.5 m/s
- Adjust based on distance between waypoints
- Slower speeds more realistic for indoor
- Faster speeds for outdoor/long distances

### 4. Troubleshooting
- Enable DEBUG_MODE to see navigation details
- Check door names match pattern
- Verify waypoint positions are accessible
- Monitor for timeout messages

## Debug Mode

Enable detailed logging:
```
DEBUG_MODE=TRUE
```

**Output examples:**
```
NAV: Start wp1 dist:15.2m time:30.4s
DOOR: Blocked by 'Main Door'
NAV: Arrived, dist:0.8m
```

## Integration with Activities

Navigation integrates seamlessly with waypoint activities:

**Movement → Activity → Movement**
1. Navigate to waypoint
2. Stop and play activity animation
3. Attach props if configured
4. Linger for specified duration
5. Move to next waypoint

**Activities still work:**
- Sitting
- Lingering
- Attachables
- Orientations
- Animations

## Performance

### Memory Usage
- **Removed:** Pathfinding event handlers (~50 lines)
- **Added:** Door detection functions (~60 lines)
- **Net change:** +54 lines total
- **Memory:** Well within LSL limits

### Computational Load
- **Ray casting:** Only when selecting waypoint
- **Timer:** Checks every 1 second during movement
- **Minimal impact:** Very lightweight

## Example Scenarios

### Scenario 1: Office Movement
**Setup:**
```
Waypoint0: Reception desk
Waypoint1: Behind door "Office Door"
Waypoint2: Conference room (through same door)
```

**Behavior:**
- If "Office Door" closed → skips waypoints 1-2
- If "Office Door" open → navigates normally
- Automatically adapts to door state

### Scenario 2: Multi-Room Navigation
**Setup:**
```
Waypoint0: Lobby
Waypoint1: Through "Main Door" to hallway
Waypoint2: Through "Main Door" to office
Waypoint3: Back in lobby
```

**Behavior:**
- Checks door before each movement
- Skips blocked waypoints
- Continues patrol when door opens

## Comparison: Old vs New

| Feature | Pathfinding (Old) | Keyframed (New) |
|---------|-------------------|-----------------|
| Setup | Complex | Simple |
| Navmesh | Required | Not needed |
| Reliability | Frequent failures | Always works |
| Obstacles | Avoids automatically | Detected via ray |
| Configuration | Region-level | Object-level |
| Failure handling | Complex error codes | Simple blocking |
| Performance | Heavy (pathfinding) | Light (linear) |

## Migration Notes

If updating from pathfinding system:

**Removed:**
- `llCreateCharacter()`
- `llNavigateTo()`
- `moving_end()` event
- `path_update()` event
- CHARACTER_* parameters

**Added:**
- `llSetKeyframedMotion()`
- Door detection functions
- Timer-based arrival detection

**Waypoints:**
- Same format, no changes needed
- Activities still work identically

## Future Enhancements

Potential improvements:

1. **Rotation detection** - Check door rotation for open/closed
2. **Multi-pattern** - Support multiple door patterns
3. **Dynamic speed** - Vary speed based on distance
4. **Path smoothing** - Bezier curves between waypoints
5. **Obstacle memory** - Remember previously blocked paths

## Conclusion

The keyframed motion system provides reliable, simple navigation without the complexity of traditional pathfinding. The door blocking feature adds intelligent obstacle avoidance while maintaining ease of use.

Configure via RoseConfig, name doors appropriately, and the system handles the rest automatically.
