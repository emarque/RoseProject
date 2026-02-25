# Waypoint Progression Fix

## Problem

Rose was getting stuck at the first waypoint, repeatedly showing:
```
[1:59:40 PM] Rose_v5: Activity timeout: Catching up on paperwork
[2:04:41 PM] Rose_v5: Activity timeout: Catching up on paperwork
```

The watchdog timer was detecting the timeout, but Rose wasn't moving to the next waypoint.

## Root Cause

In the `timer()` event handler in `[WPP]WPManager.lsl`, there was a critical logic error:

**Lines 653-679 (before fix)**:
```lsl
if (elapsed >= MAX_ACTIVITY_DURATION)
{
    llOwnerSay("Activity timeout: " + current_activity_name);
    // ... stop animations ...
    moveToNextWaypoint();
    // NO RETURN HERE! Execution continues...
}
else if (elapsed >= activity_duration)
{
    llOwnerSay("Activity done: " + current_activity_name);
    // ... stop animations ...
    moveToNextWaypoint();  // Called AGAIN!
}
```

### The Bug

1. When an activity times out (elapsed >= MAX_ACTIVITY_DURATION), the code calls `moveToNextWaypoint()`
2. **But there's no `return` statement**, so execution continues
3. The next condition `elapsed >= activity_duration` is also true (since MAX_ACTIVITY_DURATION > activity_duration)
4. So `moveToNextWaypoint()` gets called **a second time**
5. This double call causes confusion in the navigation state machine
6. Rose ends up stuck in a loop

## Solution

Added a `return;` statement after the timeout handling to prevent the double call:

**Lines 653-678 (after fix)**:
```lsl
if (elapsed >= MAX_ACTIVITY_DURATION)
{
    llOwnerSay("Activity timeout: " + current_activity_name);
    if (activity_animation != "")
    {
        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
    }
    else
    {
        stopStandAnimation();
    }
    
    // Unsit if we're sitting
    if (current_state == "SITTING")
    {
        llUnSit(llGetOwner());
        sit_target_key = NULL_KEY;
    }
    
    moveToNextWaypoint();
    return;  // ← CRITICAL FIX: Prevent double call to moveToNextWaypoint
}
```

## Files Changed

- `RoseReceptionist.LSL/[WPP]WPManager.lsl` (line 678)

## Testing

### Before Fix
```
[1:59:40 PM] Rose_v5: Activity timeout: Catching up on paperwork
[2:04:41 PM] Rose_v5: Activity timeout: Catching up on paperwork
[2:09:42 PM] Rose_v5: Activity timeout: Catching up on paperwork
```
(Stuck at same waypoint, repeating every 5 minutes)

### After Fix
```
[2:15:00 PM] Rose_v5: Activity timeout: Catching up on paperwork
[2:15:01 PM] Rose_v5: Activity: Water plants (30s)
[2:15:31 PM] Rose_v5: Activity done: Water plants
[2:15:32 PM] Rose_v5: Activity: Watering Adri's plants (30s)
```
(Progresses through waypoints normally)

## Related Issues

This fix also improves:
- Watchdog timer effectiveness (it can now actually force progression)
- State transition reliability
- Navigation timing consistency

## Additional Improvements

While fixing the main issue, also added `llUnSit()` calls to ensure Rose properly stands up when leaving a sit activity, preventing another potential stuck state.
