# DEBUG Mode Implementation

## Overview

DEBUG mode provides a comprehensive debugging and diagnostic system for the Rose Receptionist scripts. When enabled, it allows developers and troubleshooters to see detailed operational messages and access a touch-activated status menu for diagnosing issues when the character gets stuck.

### Key Features

- **Controlled Verbosity**: Turn debug messages on/off via config
- **Script Prefixes**: Each message shows which script generated it
- **Status Menu**: Touch-activated diagnostic tool (DEBUG mode only)
- **Critical Messages**: Important warnings always show, regardless of DEBUG setting
- **Non-Intrusive**: Undocumented config parameter for end users

## Implementation Details

### The debugSay() Function

Each script implements the same debugSay() function:

```lsl
// Debug output function
debugSay(string msg)
{
    if (DEBUG)
    {
        llOwnerSay("[ScriptName] " + msg);
    }
}
```

**Scripts with debugSay()**:
- `[WPP]WPManager.lsl` - Prefix: `[Manager]`
- `[WPP]WPReporter.lsl` - Prefix: `[Reporter]`
- `[WPP]WPNavigator.lsl` - Prefix: `[Navigator]`

### DEBUG Variable

Each script has:
```lsl
integer DEBUG = FALSE;  // Will be loaded from RoseConfig.txt
```

This is read from the RoseConfig notecard during initialization.

### Message Categories

**Debug Messages** (only show when DEBUG=TRUE):
- Script initialization ("Manager ready", "Navigator ready")
- Config loading progress ("Reading config...", "Config loaded")
- State transitions ("Activity: ...", "Activity done: ...")
- Navigation events ("Teleporting to...", "Sitting on target")
- Schedule changes ("Schedule transition: ...")
- Waypoint loading ("Loading wp config: ...")
- Animation changes
- Timer events

**Critical Messages** (always show):
- Warnings ("⚠️ WATCHDOG: Stuck...")
- Errors ("❌ ERROR: SUBSCRIBER_KEY not configured")
- HTTP errors ("HTTP 401: Invalid subscriber key")
- Configuration errors

## Configuration

### RoseConfig.txt

Add this line to RoseConfig.txt (intentionally undocumented for end users):

```
# Debug mode (undocumented, for development only)
DEBUG=FALSE
```

**Values**:
- `DEBUG=FALSE` - Normal operation (default)
- `DEBUG=TRUE` - Verbose debug output
- `DEBUG=1` - Also enables debug mode
- `DEBUG=true` - Also enables debug mode (case-insensitive)

### Loading

The DEBUG value is read during script initialization:

```lsl
else if (configKey == "DEBUG")
{
    DEBUG = (value == "TRUE" || value == "true" || value == "1");
}
```

## Debug Status Menu

### Overview

When DEBUG=TRUE, touching the Rose object displays a status menu with a "Status Report" button. This provides instant access to comprehensive diagnostic information.

### Activation

1. Set `DEBUG=TRUE` in RoseConfig.txt
2. Reset scripts or wait for automatic config reload
3. Touch the Rose object
4. Click "Status Report" button in the dialog

### Status Fields

The status report includes 20+ diagnostic fields:

#### State Information
- **Current State**: IDLE, WALKING, LINGERING, SITTING, INTERACTING
- **Time in State**: Seconds since last state change
- **Watchdog Timeout**: Maximum time allowed in any state

#### Waypoint Information
- **Current Waypoint Index**: Which waypoint (0-based)
- **Total Waypoints**: Number of configured waypoints
- **Active Config**: Which config file is active

#### Activity Information
- **Current Activity**: Activity name
- **Activity Type**: linger, sit, transient, etc.
- **Activity Duration**: Total duration in seconds
- **Activity Elapsed**: Time spent so far
- **Activity Remaining**: Time left in activity

#### Schedule Information
- **Schedule Period**: WORK, AFTER_WORK, NIGHT
- **Active Config**: Which waypoint config is loaded

#### Animation Information
- **Animation List**: All animations if using list
- **Current Anim Index**: Which animation is playing
- **Single Animation**: If using single animation
- **Stand Animation**: Current stand variation

#### Home/Loop Status
- **At Home**: Whether at home waypoint
- **Loop Started**: Whether patrol loop has begun

#### Waiting Information
Based on current state, shows what event is expected next:
- **WALKING**: "Waiting for: LINK_NAV_ARRIVED or LINK_NAV_TIMEOUT"
- **LINGERING/SITTING**: "Waiting for: Timer event (activity completion)"
- **IDLE**: "Waiting for: moveToNextWaypoint call"

### Example Output

```
========== STATUS REPORT ==========
Current State: LINGERING
Current Waypoint Index: 3
Total Waypoints: 20
Current Activity: Water plants
Activity Type: linger
Activity Duration: 30s
Activity Elapsed: 15s
Activity Remaining: 15s
Schedule Period: WORK
Active Config: [WPP]WaypointConfig
Animation List: anim dance 1, anim dance 2, anim dance 3
Current Anim Index: 1
Stand Animation: anim stand 2
At Home: 0
Loop Started: 1
Time in State: 15s
Watchdog Timeout: 600s
Waiting for: Timer event (activity completion)
=====================================
```

## Usage Examples

### Example 1: Normal Operation (DEBUG=FALSE)

**Output**:
```
[11:30:00] Rose_v5: ⚠️ WARNING: SUBSCRIBER_KEY not configured!
[11:30:00] Rose_v5: Add SUBSCRIBER_KEY to RoseConfig notecard
```

Only critical warnings show. No verbose debug messages.

### Example 2: Debug Mode (DEBUG=TRUE)

**Output**:
```
[11:30:00] [Manager] Waypoint Manager ready
[11:30:00] [Manager] Schedule: WORK (config: [WPP]WaypointConfig)
[11:30:00] [Manager] Reading config...
[11:30:01] [Manager] Config loaded
[11:30:01] [Manager] 20 waypoints (list len=160)
[11:30:02] [Navigator] Navigator ready
[11:30:03] [Reporter] Reporter ready
[11:30:03] [Reporter] Config loaded
[11:30:05] [Manager] Activity: Standing at my desk (15s)
[11:30:20] [Manager] Activity done: Standing at my desk
```

All operational messages show with script prefixes.

### Example 3: Character Stuck - Using Status Menu

**Scenario**: Character frozen at a waypoint, not moving.

**Steps**:
1. Enable DEBUG=TRUE in config
2. Reset scripts
3. Wait for character to get stuck
4. Touch the character
5. Click "Status Report"

**Example Output**:
```
========== STATUS REPORT ==========
Current State: LINGERING
Current Waypoint Index: 5
Total Waypoints: 20
Current Activity: Watering plants
Activity Type: linger
Activity Duration: 30s
Activity Elapsed: 300s
Activity Remaining: -270s
...
Time in State: 300s
Watchdog Timeout: 600s
Waiting for: Timer event (activity completion)
=====================================
```

**Diagnosis**: Activity elapsed (300s) exceeds duration (30s), showing activity isn't completing properly. The negative "Activity Remaining" confirms the timer isn't firing.

### Example 4: Navigation Stuck

**Status Output**:
```
Current State: WALKING
...
Time in State: 120s
Waiting for: LINK_NAV_ARRIVED or LINK_NAV_TIMEOUT
```

**Diagnosis**: Been in WALKING state for 120 seconds. Navigation timeout is 60s, so timeout event should have fired but didn't.

### Example 5: Idle Not Progressing

**Status Output**:
```
Current State: IDLE
Current Waypoint Index: -1
Total Waypoints: 20
Time in State: 180s
Waiting for: moveToNextWaypoint call
```

**Diagnosis**: Stuck in IDLE state with invalid waypoint index (-1). The moveToNextWaypoint() function isn't being called.

## Message Categories Reference

### Debug Messages (DEBUG=TRUE only)

#### Manager Script
- "Waypoint Manager ready"
- "Schedule: WORK (config: ...)"
- "Reading config..."
- "Config loaded"
- "Loading wp config: ..."
- "X waypoints (list len=Y)"
- "Activity: NAME (Xs)"
- "Activity done: NAME"
- "Activity timeout: NAME"
- "Schedule transition: WORK → AFTER_WORK"
- "Switching to ... config: ..."
- "Duration set to: Xs"
- "Single activity - duration set to period end: ..."
- "Teleporting to first waypoint..."
- "Teleport failed, using normal navigation"
- "Sitting on target"
- "Found sit target: ..."
- "No 'sit' prim found nearby"
- "Wandering enabled/disabled"

#### Reporter Script
- "Reporter ready"
- "Reading config..."
- "Config loaded"
- "Daily report: YYYY-MM-DD"
- "429 throttled"
- "429 xN"
- "HTTP XXX" (other status codes)

#### Navigator Script
- "Navigator ready"

### Critical Messages (Always Show)

#### Warnings
- "⚠️ WARNING: SUBSCRIBER_KEY not configured!"
- "⚠️ WATCHDOG: Stuck in STATE for Xs - forcing next waypoint"
- "⚠️ WATCHDOG: Still stuck after Xs - resetting script"

#### Errors
- "❌ ERROR: SUBSCRIBER_KEY not configured"
- "⚠️ HTTP 401: Invalid subscriber key"
- "Please update SUBSCRIBER_KEY in RoseConfig notecard"
- "Get your subscriber key from Rose Receptionist dashboard"

#### Configuration
- "No RoseConfig found, using defaults"
- "No wp config notecard"
- "No wp configs (list len=0)"
- "All wp blocked"

## Troubleshooting with DEBUG

### Scenario 1: Character Frozen at Waypoint

**Symptoms**: Not moving to next waypoint

**Steps**:
1. Enable DEBUG=TRUE
2. Touch character
3. Check status report

**Look For**:
- Current State (should be IDLE, LINGERING, or SITTING)
- Time in State (if > 600s, watchdog should trigger)
- Activity Remaining (if negative, timer issue)
- Waiting for (shows what event is expected)

### Scenario 2: Navigation Never Completes

**Symptoms**: Walks but doesn't arrive

**Steps**:
1. Check status during navigation
2. Note Time in State

**Look For**:
- Current State = WALKING
- Time in State approaching NAVIGATION_TIMEOUT (60s)
- Should see timeout or arrival soon

### Scenario 3: Schedule Not Transitioning

**Symptoms**: Stays in one period past time

**Steps**:
1. Check status report
2. Note Schedule Period

**Look For**:
- Schedule Period matches current time
- If mismatch, schedule check might not be running

### Scenario 4: Activities Looping Too Fast

**Symptoms**: Activities complete immediately

**Steps**:
1. Enable DEBUG
2. Watch for "Activity: NAME (Xs)" messages

**Look For**:
- Duration value in seconds
- If 0 or very small, config issue

## Best Practices

### For Developers

1. **Always Use debugSay** for informational messages
2. **Use llOwnerSay** only for critical warnings/errors
3. **Add Script Prefix** to debugSay calls for clarity
4. **Keep Messages Concise** but informative
5. **Test Both Modes** (DEBUG=TRUE and DEBUG=FALSE)

### For Operators

1. **Keep DEBUG=FALSE** in production
2. **Enable Temporarily** when troubleshooting
3. **Use Status Menu** to diagnose stuck states
4. **Check Time in State** against timeouts
5. **Review Activity Durations** for anomalies

### Performance Considerations

- **Minimal Impact**: debugSay is a simple if-check
- **No Chat Spam**: Messages only show when needed
- **Listener Overhead**: Touch menu listener only active when DEBUG=TRUE
- **Memory**: No significant memory impact

### Security Notes

- **DEBUG Undocumented**: Prevents casual users from enabling
- **Status Menu**: Only shows when DEBUG=TRUE
- **Internal Variables**: Only visible to owner
- **No Sensitive Data**: Status report doesn't expose secrets

## Related Documentation

- `SUBSCRIBER_KEY_RENAME.md` - API key rename details
- `SESSION_DEBUG_AND_SUBSCRIBER.md` - Session summary
- `WAYPOINT_CONFIGURATION_GUIDE.md` - Waypoint setup
- `SCHEDULE_BASED_ACTIVITIES.md` - Schedule system

## Summary

DEBUG mode provides powerful diagnostics without impacting normal operation. The abstracted debugSay() function makes it easy to add new debug messages, and the touch-activated status menu provides instant insight into the character's internal state for troubleshooting stuck situations.

**Key Takeaways**:
- DEBUG=FALSE for production (default)
- DEBUG=TRUE for development/troubleshooting
- Touch menu available only in DEBUG mode
- Status report shows 20+ diagnostic fields
- Critical messages always show regardless of DEBUG setting
