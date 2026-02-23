# Single Activity Duration Matching Period End

## Problem Statement

When only one activity was defined for a schedule period, it would loop at its configured duration instead of lasting until the period ended. This created an unnatural experience where the character would keep restarting the same activity repeatedly.

## Example Problem

**Scenario**: After-work period (17:00-22:00, 5 hours)

**Config**:
```
# [WPP]AfterWorkConfig
WAYPOINT0={"type":"linger","name":"relax at home","time":1800}
```
(Single activity with 30-minute duration)

**Previous Behavior**:
- 17:00: Start "relax at home" (30 minutes)
- 17:30: Activity completes, move to next waypoint
- 17:30: Since only 1 waypoint, cycle back to waypoint 0
- 17:30: Restart "relax at home" (30 minutes)
- 18:00: Activity completes, cycle again...
- (Repeats 10 times until 22:00)

**Problem**: Unnatural looping behavior, character keeps restarting same activity

## Required Behavior

**What Should Happen**:
- 17:00: Start "relax at home"
- Duration: Automatically set to 5 hours (18,000 seconds)
- 22:00: Period ends, transition to NIGHT
- No looping, single continuous activity

## Solution Implemented

### New Function: `getSecondsUntilPeriodEnd()`

**Location**: Lines 250-295 in [WPP]WPManager.lsl

**Purpose**: Calculate how many seconds remain in the current schedule period

**Algorithm**:
```
1. Get current time in minutes since midnight
2. Get period boundaries (shift_start, shift_end, night_start)
3. Determine current period (WORK, AFTER_WORK, NIGHT)
4. Calculate period end time
5. Handle midnight crossing for NIGHT period
6. Return seconds until period ends
```

**Code**:
```lsl
integer getSecondsUntilPeriodEnd()
{
    integer current_minutes = getCurrentTimeMinutes();
    integer shift_start = parseTimeToMinutes(SHIFT_START_TIME);
    integer shift_end = parseTimeToMinutes(SHIFT_END_TIME);
    integer night_start = parseTimeToMinutes(NIGHT_START_TIME);
    
    string period = getCurrentSchedulePeriod();
    integer period_end_minutes;
    
    if (period == "WORK")
    {
        period_end_minutes = shift_end;
    }
    else if (period == "AFTER_WORK")
    {
        period_end_minutes = night_start;
    }
    else // NIGHT
    {
        period_end_minutes = shift_start;
        // If we're past midnight and shift starts tomorrow
        if (current_minutes < period_end_minutes)
        {
            // We're already into the next day
            return (period_end_minutes - current_minutes) * 60;
        }
        else
        {
            // Period ends tomorrow at shift_start
            return ((1440 - current_minutes) + period_end_minutes) * 60;
        }
    }
    
    // For WORK and AFTER_WORK periods
    if (period_end_minutes > current_minutes)
    {
        return (period_end_minutes - current_minutes) * 60;
    }
    else
    {
        // Period ends tomorrow
        return ((1440 - current_minutes) + period_end_minutes) * 60;
    }
}
```

### Updated `processWaypoint()` Function

**Location**: Lines 822-833 in [WPP]WPManager.lsl

**Logic**:
1. Check if only 1 waypoint exists in current config
2. Check if waypoint is not transient (has duration)
3. Calculate seconds until period ends
4. Validate time is reasonable (>60s, <24 hours)
5. Override activity duration to match period end

**Code**:
```lsl
// If this is the only waypoint in the period, set duration to match period end
integer num_waypoints = getWaypointCount();
if (num_waypoints == 1 && activity_type != "transient")
{
    integer seconds_until_end = getSecondsUntilPeriodEnd();
    // Only override if calculated time is reasonable
    if (seconds_until_end > 60 && seconds_until_end < 86400)
    {
        activity_duration = seconds_until_end;
        llOwnerSay("Single activity - duration set to period end: " + 
                  (string)activity_duration + "s (" + 
                  (string)(activity_duration / 60) + " minutes)");
    }
}
```

## Usage Examples

### Example 1: After-Work Single Activity

**Config**:
```
# RoseConfig.txt
SHIFT_END_TIME=17:00
NIGHT_START_TIME=22:00

# [WPP]AfterWorkConfig
WAYPOINT0={"type":"linger","name":"relax at home","time":1800}
```

**Behavior**:
```
17:00:00 - Period transition: WORK → AFTER_WORK
17:00:00 - Loading [WPP]AfterWorkConfig
17:00:00 - 1 waypoints (list len=9)
17:00:00 - Teleporting to first waypoint
17:00:00 - Single activity - duration set to period end: 18000s (300 minutes)
17:00:00 - Activity: relax at home (18000s)
22:00:00 - Period transition: AFTER_WORK → NIGHT
```

**Result**: Activity runs continuously for 5 hours, no looping

### Example 2: Night Single Activity with Midnight Crossing

**Config**:
```
# RoseConfig.txt
NIGHT_START_TIME=22:00
SHIFT_START_TIME=09:00

# [WPP]NightConfig
WAYPOINT0={"type":"sit","name":"sleep","time":28800}
```

**Behavior**:
```
22:00:00 - Period transition: AFTER_WORK → NIGHT
22:00:00 - Loading [WPP]NightConfig
22:00:00 - 1 waypoints (list len=9)
22:00:00 - Teleporting to first waypoint
22:00:00 - Single activity - duration set to period end: 39600s (660 minutes)
22:00:00 - Activity: sleep (39600s)
00:00:00 - (Midnight passes, activity continues)
09:00:00 - Period transition: NIGHT → WORK
```

**Result**: Activity runs for 11 hours (22:00 to 09:00), crossing midnight properly

### Example 3: Work Day with Multiple Waypoints

**Config**:
```
# [WPP]WaypointConfig
WAYPOINT0={"type":"linger","name":"desk work","time":3600}
WAYPOINT1={"type":"linger","name":"coffee break","time":900}
WAYPOINT2={"type":"linger","name":"meeting","time":1800}
```

**Behavior**:
```
09:00:00 - Start at waypoint 0
09:00:00 - Activity: desk work (3600s)  # Uses configured duration
10:00:00 - Move to waypoint 1
10:00:00 - Activity: coffee break (900s)  # Uses configured duration
10:15:00 - Move to waypoint 2
10:15:00 - Activity: meeting (1800s)  # Uses configured duration
10:45:00 - Move to waypoint 0
... (Cycles through all waypoints normally)
```

**Result**: Multiple waypoints use their configured durations, no override

### Example 4: Very Short Period

**Scenario**: Testing with 5-minute period

**Behavior**:
```
Period ends in 4 minutes (240 seconds)
if (seconds_until_end > 60 && seconds_until_end < 86400)  # TRUE
activity_duration = 240;
llOwnerSay("Single activity - duration set to period end: 240s (4 minutes)");
```

**Result**: Duration set to 4 minutes

### Example 5: Period Less Than 1 Minute

**Scenario**: Period ends in 45 seconds

**Behavior**:
```
Period ends in 45 seconds
if (seconds_until_end > 60 && seconds_until_end < 86400)  # FALSE (45 < 60)
# Duration NOT overridden, uses configured value
```

**Result**: Uses original configured duration (safety check)

### Example 6: Very Long Period (Edge Case)

**Scenario**: Somehow calculated >24 hours

**Behavior**:
```
Period ends in 90000 seconds (25 hours)
if (seconds_until_end > 60 && seconds_until_end < 86400)  # FALSE (90000 > 86400)
# Duration NOT overridden, uses configured value
```

**Result**: Uses original configured duration (safety check)

### Example 7: Transient Waypoint

**Config**:
```
# [WPP]AfterWorkConfig
WAYPOINT0={"type":"transient"}
```

**Behavior**:
```
if (num_waypoints == 1 && activity_type != "transient")  # FALSE
# Duration NOT overridden
# Character immediately moves to next waypoint (loops)
```

**Result**: Transient waypoints are ignored (they have no duration anyway)

### Example 8: HOME_WAYPOINT Interaction

**Config**:
```
# RoseConfig.txt
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=5

# [WPP]WaypointConfig
WAYPOINT0={"type":"linger","name":"home base","time":300}
```

**Behavior**:
```
if (wpNumber == HOME_WAYPOINT)
{
    activity_duration = (5 * 60);  # 300 seconds
}

# Then if single activity check...
if (num_waypoints == 1)
{
    integer seconds_until_end = getSecondsUntilPeriodEnd();  # e.g. 28800
    activity_duration = 28800;  # Override HOME duration
}
```

**Result**: Single-activity override takes precedence over HOME_WAYPOINT duration

## Midnight Crossing Details

### NIGHT Period Calculation

The NIGHT period is special because it crosses midnight (e.g., 22:00 to 09:00).

**Case 1: Before Midnight**
```
Current time: 23:30 (1410 minutes)
Period ends: 09:00 (540 minutes) tomorrow

Calculation:
- Minutes until midnight: 1440 - 1410 = 30
- Minutes from midnight to shift_start: 540
- Total: 30 + 540 = 570 minutes
- Seconds: 570 * 60 = 34200 seconds (9.5 hours)
```

**Case 2: After Midnight**
```
Current time: 02:00 (120 minutes)
Period ends: 09:00 (540 minutes) today

Calculation:
- Simple subtraction: 540 - 120 = 420 minutes
- Seconds: 420 * 60 = 25200 seconds (7 hours)
```

## Testing

### Manual Testing Steps

1. **Set up single activity config**
```
# Create [WPP]AfterWorkConfig with 1 waypoint
WAYPOINT0={"type":"linger","name":"test activity","time":300}
```

2. **Wait for period transition**
- Approach 17:00 (or whatever SHIFT_END_TIME is)
- Watch chat for messages

3. **Verify messages**
```
Expected:
"Switching to AFTER_WORK waypoint config: [WPP]AfterWorkConfig"
"Loading wp config: [WPP]AfterWorkConfig"
"1 waypoints (list len=9)"
"Teleporting to first waypoint of new schedule"
"Single activity - duration set to period end: 18000s (300 minutes)"
"Activity: test activity (18000s)"
```

4. **Wait for next period transition**
- Activity should continue without looping
- At 22:00, should transition to NIGHT period

### Validation Checklist

- [ ] Single activity message appears
- [ ] Duration matches period length
- [ ] No looping before period ends
- [ ] Smooth transition to next period
- [ ] Multiple waypoint configs unaffected
- [ ] Transient waypoints ignored
- [ ] Midnight crossing works (NIGHT period)
- [ ] Short periods (<1 min) use configured duration
- [ ] Very long periods (>24h) use configured duration

## Troubleshooting

### Issue: Activity still loops

**Possible Causes**:
1. Multiple waypoints in config (check with "X waypoints" message)
2. Transient waypoint (no duration override for transient)
3. Duration calculation failed safety check

**Solution**:
- Verify config has exactly 1 waypoint
- Check that waypoint type is "linger" or "sit", not "transient"
- Check diagnostic message for calculated duration

### Issue: Wrong duration calculated

**Diagnostic Message**:
```
"Single activity - duration set to period end: 240s (4 minutes)"
```

**Check**:
1. Verify RoseConfig.txt has correct times
2. Check current SLT time
3. Verify timezone_offset setting
4. Look for period end time in schedule

**Common Problem**: Timezone offset incorrect
- Default is -8 (PST/SLT)
- If your schedule uses different timezone, adjust offset

### Issue: No duration override message

**Check**:
1. Is there more than 1 waypoint? ("X waypoints" should show 1)
2. Is waypoint transient? (check waypoint config)
3. Is calculated time outside safety range? (check actual period times)

### Issue: Duration seems wrong for NIGHT period

**Remember**: NIGHT period crosses midnight

**Example**:
- NIGHT_START_TIME=22:00
- SHIFT_START_TIME=09:00
- Duration should be ~11 hours (39600 seconds)

**Check**:
- Current time vs period boundaries
- Midnight crossing logic
- Diagnostic message shows calculated value

## Benefits

✅ **Natural Behavior**: Single activities span entire period
✅ **No Looping**: Character doesn't restart same activity
✅ **Automatic Duration**: No need to calculate period length manually
✅ **Flexible**: Works with any period length
✅ **Safe**: Validation prevents unreasonable durations
✅ **Midnight Safe**: Properly handles NIGHT period crossing midnight
✅ **Diagnostic**: Clear messages show what's happening
✅ **Non-Intrusive**: Multiple waypoints work normally

## Edge Cases Handled

### Safety Checks
- Minimum 60 seconds (prevents <1 minute periods)
- Maximum 86400 seconds (prevents >24 hour calculations)
- Falls back to configured duration if outside range

### Midnight Crossing
- NIGHT period properly handles 22:00-09:00 span
- Works before and after midnight
- Correct calculation in both cases

### Waypoint Types
- Only applies to "linger" and "sit" types
- Transient waypoints ignored (have no duration)
- HOME_WAYPOINT can be overridden

### Multiple Waypoints
- Only activates when exactly 1 waypoint
- Multiple waypoints use configured durations
- Clean detection, no interference

## Related Documentation

- SCHEDULE_BASED_ACTIVITIES.md
- SCHEDULE_QUICK_REFERENCE.md
- SCHEDULE_TRANSITION_FREEZE_FIX.md
- WAYPOINT_CONFIGURATION_GUIDE.md

## Files Modified

- `RoseReceptionist.LSL/[WPP]WPManager.lsl`
  - Function: `getSecondsUntilPeriodEnd()` (NEW)
  - Function: `processWaypoint()` (MODIFIED)
  - Lines: 250-295 (new function)
  - Lines: 822-833 (duration override logic)
