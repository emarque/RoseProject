# Watchdog Timer Fix

## Problem

Rose was getting stuck at waypoints or during navigation with no automatic recovery mechanism. Once stuck, she would remain in that state indefinitely until the script was manually reset.

## Root Cause

While the system had individual timeouts for specific scenarios:
- Navigator had 60-second timeout for navigation (NAVIGATION_TIMEOUT)
- Manager had 300-second timeout for activities (MAX_ACTIVITY_DURATION)

There was no overall watchdog to catch edge cases where:
- State transition logic failed
- Link messages were lost
- Unexpected conditions left the system in a hung state

## Solution

Implemented a comprehensive watchdog timer system in `[WPP]WPManager.lsl` that monitors state changes and forces recovery.

### New Variables

```lsl
integer WATCHDOG_TIMEOUT = 600;  // 10 minutes maximum in any state
integer last_state_change_time = 0;
string last_known_state = "IDLE";
```

### New Functions

#### updateState(string new_state)
```lsl
updateState(string new_state)
{
    if (new_state != current_state)
    {
        current_state = new_state;
        last_state_change_time = llGetUnixTime();
        last_known_state = new_state;
    }
}
```

Replaces all direct assignments to `current_state`. Automatically resets the watchdog timer whenever the state changes.

#### checkWatchdog()
```lsl
checkWatchdog()
{
    integer time_in_state = llGetUnixTime() - last_state_change_time;
    
    if (time_in_state > WATCHDOG_TIMEOUT)
    {
        llOwnerSay("⚠️ WATCHDOG: Stuck in " + current_state + " for " + 
                   (string)time_in_state + "s - forcing next waypoint");
        
        // Stop any animations
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
        }
        stopStandAnimation();
        
        // Force move to next waypoint
        moveToNextWaypoint();
        
        // If still stuck after attempting to move, reset the script
        if (time_in_state > WATCHDOG_TIMEOUT * 2)
        {
            llOwnerSay("⚠️ WATCHDOG: Still stuck after " + (string)time_in_state + 
                       "s - resetting script");
            llResetScript();
        }
    }
}
```

Called on every timer tick to check if Rose has been in the same state too long.

### Implementation Changes

**All state changes now use updateState():**

1. `toggleWander()`: `updateState("IDLE")`
2. `processWaypoint()`: `updateState("LINGERING")` or `updateState("SITTING")`
3. `moveToNextWaypoint()`: `updateState("WALKING")`
4. `link_message()`: `updateState("INTERACTING")` or `updateState("IDLE")`

**Timer function enhanced:**
```lsl
timer()
{
    // Always check watchdog first
    checkWatchdog();
    
    // ... rest of timer logic
}
```

**Initialization in state_entry:**
```lsl
state_entry()
{
    // Initialize watchdog timer
    last_state_change_time = llGetUnixTime();
    updateState("IDLE");
    
    // ... rest of initialization
}
```

## Watchdog Behavior

### Level 1: Gentle Recovery (10 minutes)
If Rose is stuck in any state for more than 10 minutes:
1. Logs diagnostic message showing stuck state
2. Stops any playing animations
3. Forces move to next waypoint
4. Resets watchdog timer

### Level 2: Hard Reset (20 minutes)
If Rose is STILL stuck 10 minutes after Level 1 intervention:
1. Logs that recovery failed
2. Performs full script reset via `llResetScript()`

### States Monitored

The watchdog monitors ALL states:
- `"IDLE"` - Waiting to start
- `"WALKING"` - Navigating to waypoint
- `"LINGERING"` - At linger activity waypoint
- `"SITTING"` - At sit activity waypoint  
- `"INTERACTING"` - Greeting/chatting with visitor

## Diagnostic Messages

When watchdog triggers, you'll see messages like:
```
⚠️ WATCHDOG: Stuck in LINGERING for 612s - forcing next waypoint
```

Or if hard reset needed:
```
⚠️ WATCHDOG: Still stuck after 1224s - resetting script
```

These messages help identify:
- Which state caused the stuck condition
- How long Rose was stuck
- What recovery action was taken

## Testing

To test the watchdog:

1. **Simulate stuck navigation:**
   - Remove waypoint prim Rose is trying to reach
   - Wait 10+ minutes
   - Watchdog should force next waypoint

2. **Simulate stuck activity:**
   - Set very long activity duration (>10 min)
   - Wait for watchdog
   - Should force move to next waypoint

3. **Verify recovery:**
   - After watchdog triggers, verify Rose continues normal operation
   - Check she doesn't get stuck again

## Configuration

To adjust watchdog timeout:
```lsl
integer WATCHDOG_TIMEOUT = 600;  // Adjust in seconds (default: 10 minutes)
```

Recommended values:
- **600** (10 min) - Default, good for most cases
- **300** (5 min) - More aggressive recovery
- **900** (15 min) - More patient, for very long activities

## Benefits

1. **Self-Healing**: Rose automatically recovers from stuck states
2. **Diagnostic**: Clear messages identify problem states
3. **Layered**: Gentle recovery first, hard reset as last resort
4. **Comprehensive**: Monitors ALL states, not just specific scenarios
5. **Minimal Impact**: Only acts when truly stuck, doesn't interfere with normal operation

## Related Issues

This fix addresses:
- Rose getting stuck during navigation
- Rose getting stuck at activities
- Rose getting stuck at home waypoint
- Loss of link messages causing hung states
- Any unexpected condition causing infinite loops
