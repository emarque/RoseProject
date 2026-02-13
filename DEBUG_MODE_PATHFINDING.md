# Debug Mode and Pathfinding Diagnostics

## Overview

This document describes the debug mode feature and pathfinding diagnostics added to help diagnose navigation issues where the character gets stuck or fails to reach waypoints.

## Problem Statement

The pathfinding system was experiencing issues:
- Character would get stuck often
- Failed to reach even the first waypoint
- No diagnostic information about why navigation was failing
- Difficult to troubleshoot navmesh or configuration issues

## Solution

Added a configurable debug mode with comprehensive pathfinding diagnostics through the `path_update` event handler.

## Configuration

### Enabling Debug Mode

Edit the `RoseConfig` notecard and set:

```
DEBUG_MODE=TRUE
```

Or keep it disabled (default):

```
DEBUG_MODE=FALSE
```

The scripts automatically reload when the notecard is saved.

### Accepted Values

- `TRUE`, `true`, `1` = Debug mode enabled
- `FALSE`, `false`, `0` = Debug mode disabled (default)

## Features

### 1. Path Update Event Handler

The `path_update` event is triggered by the LSL pathfinding system during navigation with status updates. This provides real-time information about pathfinding successes and failures.

### 2. Navigation Failure Logging

**All navigation failures are ALWAYS logged**, regardless of debug mode setting. This ensures critical issues are visible even with debug mode off.

#### Failure Types

| Type | Code | Always Logged | Message |
|------|------|---------------|---------|
| Invalid Start | 4 | ✅ Yes | Character may be off navmesh |
| Invalid Goal | 5 | ✅ Yes | Waypoint may be off navmesh |
| Unreachable | 6 | ✅ Yes | No path exists |
| Target Gone | 7 | ✅ Yes | Target disappeared |
| No Navmesh | 8 | ✅ Yes | Region may not have pathfinding enabled |
| Pathfinding Disabled | 9 | ✅ Yes | Parcel pathfinding is disabled |
| Parcel Unreachable | 10 | ✅ Yes | Parcel boundary blocks path |
| Other Failure | 11 | ✅ Yes | Unknown failure |

### 3. Debug Mode Detailed Logging

When debug mode is enabled, additional diagnostic information is logged:

#### Navigation Start
```
🚶 DEBUG: Starting navigation to waypoint 1
   From: <120, 125, 25>
   To: <140, 145, 25>
   Distance: 28.28m
```

#### Navigation Success
```
🎯 DEBUG: Path update - Goal reached
✅ DEBUG: Navigation completed - moving_end event received
   Final position: <140, 145, 25.1>
```

#### Near Waypoint
```
🎯 DEBUG: Close to waypoint (0.85m), processing arrival
```

#### Navigation Timeout
```
⏱️ Navigation timeout (60s) - moving to next waypoint
   Stuck at: <125, 128, 25>
   Target was: <140, 145, 25>
   Distance remaining: 21.21m
```

## Example Scenarios

### Scenario 1: Waypoint Off Navmesh

**Symptom:** Character starts moving but immediately stops.

**Debug Output:**
```
🚶 DEBUG: Starting navigation to waypoint 1
   From: <120, 125, 25>
   To: <140, 145, 25>
   Distance: 28.28m
❌ PATHFINDING FAILURE: Invalid goal location - waypoint may be off navmesh
   Target position: <140, 145, 25>
   Waypoint index: 1
```

**Solution:** Move waypoint to be on the navmesh or rebake navmesh.

### Scenario 2: Character Off Navmesh

**Symptom:** Character won't start moving at all.

**Debug Output:**
```
❌ PATHFINDING FAILURE: Invalid start location - character may be off navmesh
   Current position: <120, 125, 25>
```

**Solution:** Move character to navmesh or rebake navmesh.

### Scenario 3: No Navmesh in Region

**Symptom:** Character won't move, fails on every waypoint.

**Debug Output:**
```
❌ PATHFINDING FAILURE: No navmesh at location
   This region may not have pathfinding enabled or navmesh is incomplete
   Current position: <120, 125, 25>
```

**Solution:** Enable pathfinding in region and bake navmesh.

### Scenario 4: Parcel Pathfinding Disabled

**Symptom:** Character won't move on certain parcels.

**Debug Output:**
```
❌ PATHFINDING FAILURE: Dynamic pathfinding disabled on this parcel
   Ask parcel owner to enable pathfinding in About Land settings
```

**Solution:** Enable pathfinding in parcel settings (About Land → Options → Allow Scripts → Pathfinding).

### Scenario 5: Path Blocked by Obstacle

**Symptom:** Character gets stuck partway to waypoint.

**Debug Output:**
```
❌ PATHFINDING FAILURE: Goal unreachable - no path exists
   From: <125, 128, 25> To: <140, 145, 25>
   Distance: 21.21m
```

**Solution:** Check for obstacles, ensure clear path, or add intermediate waypoints.

### Scenario 6: Timeout (Stuck)

**Symptom:** Character stops moving after 60 seconds.

**Debug Output:**
```
⏱️ Navigation timeout (60s) - moving to next waypoint
   Stuck at: <125, 128, 25>
   Target was: <140, 145, 25>
   Distance remaining: 21.21m
```

**Solution:** Check for obstacles, adjust waypoint positions, or increase timeout.

## Troubleshooting Guide

### Character Won't Move At All

1. **Enable debug mode** in RoseConfig
2. **Check console output** for pathfinding failures
3. **Common causes:**
   - No navmesh in region (rebake navmesh)
   - Character off navmesh (reposition character)
   - Pathfinding disabled on parcel (enable in About Land)

### Character Gets Stuck Partway

1. **Enable debug mode** to see where it gets stuck
2. **Check for obstacles** between waypoints
3. **Verify navmesh continuity** - gaps will cause failures
4. **Consider:**
   - Adding intermediate waypoints
   - Adjusting CHARACTER_RADIUS and CHARACTER_LENGTH
   - Checking for parcel boundaries

### Character Reaches Some Waypoints But Not Others

1. **Enable debug mode** to identify problematic waypoints
2. **Check specific waypoint positions:**
   - Are they on navmesh?
   - Are they reachable from previous waypoint?
   - Are they inside parcel boundaries?
3. **Review path_update failures** for specific waypoints

## Technical Details

### Path Update Event Constants

From LSL Wiki, the path_update event type parameter:

| Constant | Value | Description |
|----------|-------|-------------|
| PU_GOAL_REACHED | 0 | Successfully reached target |
| PU_SLOWDOWN_DISTANCE_REACHED | 1 | Approaching target, slowing down |
| PU_EVADE_HIDDEN | 2 | Hiding from threat (not used) |
| PU_EVADE_SPOTTED | 3 | Threat spotted (not used) |
| PU_FAILURE_INVALID_START | 4 | Start location invalid/off navmesh |
| PU_FAILURE_INVALID_GOAL | 5 | Goal location invalid/off navmesh |
| PU_FAILURE_UNREACHABLE | 6 | Goal unreachable, no path |
| PU_FAILURE_TARGET_GONE | 7 | Target object disappeared |
| PU_FAILURE_NO_NAVMESH | 8 | No navmesh at location |
| PU_FAILURE_DYNAMIC_PATHFINDING_DISABLED | 9 | Parcel blocks pathfinding |
| PU_FAILURE_PARCEL_UNREACHABLE | 10 | Cannot cross parcel boundary |
| PU_FAILURE_OTHER | 11 | Other/unknown failure |

### Implementation Notes

1. **Always-On Failure Logging**: Critical failures are logged regardless of debug mode to ensure visibility of navigation problems.

2. **Detailed Success Logging**: Success events (goal reached, slowdown) only log in debug mode to avoid spam.

3. **Position Information**: All failure messages include position information to help locate problems.

4. **Distance Calculations**: Shows distance remaining to help assess if waypoint is truly unreachable or if navigation just failed.

5. **Timer-Based Fallback**: 60-second timeout ensures character doesn't get permanently stuck.

## Performance Considerations

### Debug Mode Off (Default)

- Minimal impact - only logs failures
- Suitable for production use
- Still provides critical diagnostic information

### Debug Mode On

- More verbose logging
- Useful for troubleshooting
- May generate significant console output during active navigation
- Should be disabled once issues are resolved

## Best Practices

1. **Start with debug mode off** - Only enable when troubleshooting
2. **Check console immediately** when character gets stuck
3. **Document failure messages** - They contain specific information about the problem
4. **Test waypoints individually** - Enable debug mode and test one waypoint at a time
5. **Verify navmesh** - Most issues are navmesh-related
6. **Check parcel settings** - Pathfinding must be enabled

## Related Files

- `RoseReceptionist.LSL/RoseConfig.txt` - Configuration file with DEBUG_MODE setting
- `RoseReceptionist.LSL/RoseReceptionist_GoWander3.lsl` - Navigation script with path_update handler
- `TOUCH_PATHFINDING_ANIMATION_FIXES.md` - Related pathfinding parameter documentation

## Future Enhancements

Potential improvements to consider:

1. **Retry Logic**: Automatically retry failed paths after repositioning
2. **Alternative Routes**: Try different navigation options on failure
3. **Navmesh Validation**: Pre-validate waypoints before attempting navigation
4. **Performance Metrics**: Track success rate and average navigation times
5. **Smart Timeout**: Adjust timeout based on distance to target

## Conclusion

The debug mode and path_update event handler provide comprehensive diagnostics for pathfinding issues. By logging all failures and providing detailed information in debug mode, administrators can quickly identify and resolve navigation problems.

Enable debug mode when troubleshooting, check console output for specific failure types, and use the information to adjust waypoint positions, fix navmesh issues, or modify parcel settings.
