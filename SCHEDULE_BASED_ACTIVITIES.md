# Schedule-Based Activity System

## Overview

The Rose Receptionist now supports time-based activity scheduling with three distinct periods throughout the day: work hours, after-work hours, and night hours. Each period has its own waypoint configuration, allowing Rose to follow realistic daily routines.

## Schedule Periods

### 1. Work Hours (Receptionist Duties)
**Default Time**: 09:00 - 17:00
**Config File**: `[WPP]WaypointConfig`

During work hours, Rose performs her receptionist duties:
- Greeting visitors
- Answering questions
- Performing work-related activities
- Following her regular work waypoint loop

**Announcement**: When returning to work in the morning:
```
"Good morning everyone! I'm back at work."
```

### 2. After-Work Hours (Personal Time)
**Default Time**: 17:00 - 22:00 (SHIFT_END_TIME to NIGHT_START_TIME)
**Config File**: `[WPP]AfterWorkConfig.notecard`

After her shift ends, Rose transitions to after-work activities:
- Relaxing with colleagues
- Social time
- Personal errands
- Tidying up workspace
- Checking personal messages

**Announcement**: When leaving work:
```
"Well everyone, my shift is over! I'll see you all tomorrow. Have a great evening!"
```

### 3. Night Hours (Home and Rest)
**Default Time**: 22:00 - 09:00 (NIGHT_START_TIME to SHIFT_START_TIME)
**Config File**: `[WPP]NightConfig.notecard`

During night hours, Rose goes home and rests:
- Walking home
- Preparing for bed
- Sleeping (long duration activities)
- Morning routine
- Returning to work waypoint

## Configuration

### RoseConfig.txt Settings

```ini
# Work shift hours (when Rose is on duty as receptionist)
SHIFT_START_TIME=09:00
SHIFT_END_TIME=17:00

# Night time start (when night activities begin)
# Activities after work shift but before night start are "after work" activities
# Night activities run from NIGHT_START_TIME until next SHIFT_START_TIME
NIGHT_START_TIME=22:00
```

**Time Format**: HH:MM in 24-hour format

### Customizing Schedule Times

You can adjust the schedule to fit your needs:

```ini
# Early bird schedule
SHIFT_START_TIME=07:00
SHIFT_END_TIME=15:00
NIGHT_START_TIME=20:00

# Night shift schedule
SHIFT_START_TIME=22:00
SHIFT_END_TIME=06:00
NIGHT_START_TIME=14:00

# Part-time schedule
SHIFT_START_TIME=10:00
SHIFT_END_TIME=14:00
NIGHT_START_TIME=22:00
```

## Waypoint Configuration Files

### Work Config: [WPP]WaypointConfig
This is the existing waypoint configuration file used for work activities. Continue using it as normal for receptionist duties during work hours.

### After-Work Config: [WPP]AfterWorkConfig.notecard

Create this file with waypoints for after-work activities. Example:

```
# Stop by the break room
WAYPOINT0={"type":"linger","name":"relaxing in break room","orientation":180,"time":300,"animation":"casual_stand","attachments":[{"item":"Coffee Mug","point":"RightHand"}]}

# Social time with coworkers
WAYPOINT1={"type":"linger","name":"chatting with colleagues","orientation":90,"time":180,"animation":"friendly_talk","attachments":[]}

# Check personal messages
WAYPOINT2={"type":"sit","name":"checking messages","time":240,"animation":"typing","attachments":[]}
```

### Night Config: [WPP]NightConfig.notecard

Create this file with waypoints for night and home activities. Example:

```
# Go to bedroom
WAYPOINT0={"type":"transient","name":"walking to bedroom"}

# Get ready for bed
WAYPOINT1={"type":"linger","name":"getting ready for bed","orientation":270,"time":180,"animation":"casual_stand","attachments":[]}

# Sleep (8 hours = 28800 seconds)
WAYPOINT2={"type":"sit","name":"sleeping","time":28800,"animation":"sleep","attachments":[]}

# Morning routine
WAYPOINT3={"type":"linger","name":"morning routine","orientation":0,"time":300,"animation":"casual_stand","attachments":[]}
```

**Note**: For sleep or other long activities, use large time values. The system will loop through the night config until morning.

## Schedule Transition Behavior

### How Transitions Work

1. **Timer Check**: Every 60 seconds, the system checks if the schedule period has changed
2. **Period Detection**: Determines if we're in WORK, AFTER_WORK, or NIGHT period
3. **Transition**: If period changed:
   - Announces the transition
   - Stops current activity gracefully
   - Switches to appropriate waypoint config
   - Resets waypoint index to start from beginning
   - Begins following new schedule

### Mid-Activity Transitions

If a schedule transition occurs while Rose is in the middle of an activity:
- Current activity completes normally
- Announcement is made
- New config takes effect
- Next waypoint comes from new schedule

This ensures smooth, non-disruptive transitions.

### Startup Behavior

When the script starts (or resets) at any time:
- Automatically detects current time period
- Loads appropriate config for that period
- Begins activities from that schedule
- Announces which schedule is active

Example startup messages:
```
Waypoint Manager ready
Schedule: WORK (config: [WPP]WaypointConfig)
Reading config...
Config loaded
Loading wp config: [WPP]WaypointConfig
20 waypoints (list len=160)
```

## Time Handling Details

### Midnight Crossing

The NIGHT period automatically handles midnight crossing:
- NIGHT_START_TIME (22:00) to SHIFT_START_TIME (09:00)
- Works correctly even though it spans across midnight
- No special configuration needed

### Schedule Check Frequency

- Schedule is checked every 60 seconds
- Configurable via `SCHEDULE_CHECK_INTERVAL` (in seconds)
- Low overhead - doesn't impact performance

### Time Calculation

Times are calculated using Second Life server time:
- Always consistent and reliable
- Uses `llGetTimestamp()` for current time
- Converts to minutes since midnight for comparison
- Handles all edge cases automatically

## Example Daily Routine

Here's a complete day in Rose's life:

**08:55** - Script running, currently in NIGHT period, finishing morning routine
**09:00** - Schedule switches to WORK
- Message: "Good morning everyone! I'm back at work."
- Begins work waypoint loop

**09:05-17:00** - Following work waypoints
- Greeting visitors
- Reception desk duties
- Various work activities

**17:00** - Schedule switches to AFTER_WORK
- Message: "Well everyone, my shift is over! I'll see you all tomorrow. Have a great evening!"
- Begins after-work waypoint loop

**17:05-22:00** - Following after-work waypoints
- Relaxing with friends
- Personal time
- Tidying up

**22:00** - Schedule switches to NIGHT
- Message: "⏰ Schedule transition: AFTER_WORK → NIGHT"
- Begins night waypoint loop

**22:05-08:55** - Following night waypoints
- Walking home
- Getting ready for bed
- Sleeping
- Morning routine
- Returns to work waypoint

**09:00** - Cycle repeats

## Troubleshooting

### Rose Not Switching Schedules

**Check**:
1. Verify SHIFT_START_TIME, SHIFT_END_TIME, and NIGHT_START_TIME are set correctly
2. Check config files exist: `[WPP]AfterWorkConfig.notecard` and `[WPP]NightConfig.notecard`
3. Look for schedule transition messages in chat
4. Verify times are in HH:MM format (24-hour)

**Common Issues**:
- Config notecards don't exist → Create them with at least one waypoint
- Times in wrong format → Use HH:MM (e.g., "09:00" not "9:00 AM")
- Times don't make sense → Ensure shift_end < night_start for normal schedules

### Empty Config Notecards

If a config notecard is empty or doesn't exist:
- Script will load it but find 0 waypoints
- Rose will stay at current location
- Create the notecard with example waypoints to fix

### Announcement Not Showing

The shift end announcement only shows:
- When transitioning FROM work TO after-work
- Once per transition (won't repeat)
- In public chat (not owner say)
- If you miss it, wait for next day's transition

### Testing Schedule Transitions

To test without waiting for real schedule times:

1. **Temporarily adjust times** in RoseConfig.txt:
```ini
SHIFT_START_TIME=12:00
SHIFT_END_TIME=12:05
NIGHT_START_TIME=12:10
```

2. **Reset the script** at 11:59
3. **Watch transitions** occur at 12:00, 12:05, 12:10

4. **Restore real times** after testing

## Advanced Usage

### Multiple Shifts

For environments with multiple shifts, you can configure overlapping or sequential schedules by adjusting the times and using appropriate waypoint configs.

### Weekend vs Weekday

Currently, the system doesn't distinguish days of week. For weekend-only schedules, you would need to manually adjust configs or temporarily disable waypoints.

### Seasonal Schedules

Different seasons could have different operating hours. Simply adjust the times in RoseConfig.txt when seasons change.

## Technical Implementation

### Architecture

The schedule system is implemented entirely in `[WPP]WPManager.lsl`:
- ~170 lines of new code
- 7 new functions for time handling
- 9 new variables for state tracking
- Integrated with existing waypoint system

### Performance

- Minimal overhead (check every 60 seconds)
- No additional HTTP requests
- No additional sensors
- Same memory usage as single config system
- Efficient time calculations

### Compatibility

- Fully backward compatible
- Existing work waypoint configs continue working
- If new configs don't exist, system gracefully handles it
- No breaking changes to existing functionality

## Summary

The schedule-based activity system adds realistic time-of-day behavior to Rose:

✅ **Three distinct activity periods**
✅ **Seamless automatic transitions**
✅ **Configurable time ranges**
✅ **Separate waypoint configs per period**
✅ **Natural announcements**
✅ **Handles midnight crossing**
✅ **Works at any startup time**
✅ **Backward compatible**

This creates a much more immersive and realistic experience, making Rose feel like a living character with a daily routine rather than just a script following waypoints.
