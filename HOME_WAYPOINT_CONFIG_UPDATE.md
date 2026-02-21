# Home Waypoint Configuration Update

## Problem

The configuration system used old format with position coordinates:
```
HOME_POSITION=<128, 128, 25>
HOME_DURATION=300  # Duration in seconds
```

But the user wanted a waypoint-based system:
- Specify home as a waypoint NUMBER (not coordinates)
- Default to waypoint 0
- Duration in MINUTES (not seconds)

## Solution

Updated `RoseConfig.txt` to use the new format that the code already supported!

### Old Configuration (REMOVED)
```
HOME_POSITION=<128, 128, 25>
HOME_DURATION=300
```

### New Configuration (CURRENT)
```
# Home Waypoint Configuration
# Waypoint number to use as "home" (default: 0)
# Rose will stay at this waypoint for HOME_DURATION_MINUTES when wandering begins
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=0
```

## How It Works

### Code Implementation

The code in `[WPP]WPManager.lsl` already had full support for this (lines 474-500):

```lsl
// Check if should start at home waypoint
if (HOME_WAYPOINT >= 0 && !loop_started)
{
    integer home_index = findWaypointIndexByNumber(HOME_WAYPOINT);
    if (home_index != -1)
    {
        current_waypoint_index = home_index;
        at_home = TRUE;
        home_start_time = llGetUnixTime();
        loop_started = TRUE;
    }
    else
    {
        llOwnerSay("Home wp " + (string)HOME_WAYPOINT + " not found");
        current_waypoint_index = 0;
        loop_started = TRUE;
    }
}

// Check if still at home
if (at_home && HOME_DURATION_MINUTES > 0)
{
    integer elapsed_minutes = (llGetUnixTime() - home_start_time) / 60;
    
    if (elapsed_minutes < HOME_DURATION_MINUTES)
    {
        // Stay at home - set timer to check again
        integer remaining = (HOME_DURATION_MINUTES - elapsed_minutes) * 60;
        llSetTimerEvent((float)remaining);
        return;
    }
    
    at_home = FALSE;
}
```

### Configuration Reading

Config parser (lines 747-753) reads both values:
```lsl
else if (configKey == "HOME_WAYPOINT")
{
    HOME_WAYPOINT = (integer)value;
}
else if (configKey == "HOME_DURATION_MINUTES")
{
    HOME_DURATION_MINUTES = (integer)value;
}
```

### Default Change

Changed default value from `-1` (disabled) to `0` (waypoint 0):
```lsl
// OLD:
integer HOME_WAYPOINT = -1;

// NEW:
integer HOME_WAYPOINT = 0;  // Default to waypoint 0
```

## Usage Examples

### Example 1: No Home Waiting
```
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=0
```
**Behavior**: Rose starts at waypoint 0 but immediately begins patrol (no waiting).

### Example 2: Wait at Reception Desk
```
HOME_WAYPOINT=0
HOME_DURATION_MINUTES=5
```
**Behavior**: Rose starts at waypoint 0 (reception desk) and waits there for 5 minutes before starting patrol.

### Example 3: Custom Home Location
```
HOME_WAYPOINT=3
HOME_DURATION_MINUTES=10
```
**Behavior**: Rose starts at waypoint 3 and waits there for 10 minutes before patrol.

### Example 4: Disabled Home (Old Behavior)
```
HOME_WAYPOINT=-1
HOME_DURATION_MINUTES=0
```
**Behavior**: Rose immediately starts random patrol without going home first.

## Benefits

1. **Simpler Configuration**: Use waypoint numbers instead of coordinates
2. **Consistent with Waypoints**: Home is just another waypoint
3. **Easier to Update**: Change waypoint location by moving prim, no config update needed
4. **More Intuitive**: Minutes instead of seconds for duration
5. **Backward Compatible**: Can still disable with `HOME_WAYPOINT=-1`

## Migration Guide

If you have an old config with `HOME_POSITION`:

### Step 1: Identify Your Home Waypoint
Look at your waypoint config and find which waypoint number corresponds to your home position.

### Step 2: Convert Duration
If you had `HOME_DURATION=300`, that's 300 seconds = 5 minutes.
Set `HOME_DURATION_MINUTES=5`.

### Step 3: Update Config
Replace:
```
HOME_POSITION=<128, 128, 25>
HOME_DURATION=300
```

With:
```
HOME_WAYPOINT=0  # or your home waypoint number
HOME_DURATION_MINUTES=5  # or your desired minutes
```

### Step 4: Remove Old Lines
Delete the old `HOME_POSITION` and `HOME_DURATION` lines from your config.

## Troubleshooting

### Rose says "Home wp X not found"
Your configured HOME_WAYPOINT number doesn't exist in your waypoint config.
- Check your `[WPP]WaypointConfig` notecard
- Ensure you have a `WAYPOINTX` entry matching your HOME_WAYPOINT number
- Common issue: HOME_WAYPOINT=5 but you only have 0-4 defined

### Rose doesn't wait at home
Check that:
1. `HOME_DURATION_MINUTES` is greater than 0
2. `HOME_WAYPOINT` is valid (>= 0)
3. Waypoint exists in your config
4. Rose's wandering is enabled (`WANDER_ENABLED=TRUE`)

### Rose immediately starts patrol
This is normal if `HOME_DURATION_MINUTES=0`. She goes to home waypoint but doesn't wait.

## Technical Details

### Waypoint Lookup
The system uses `findWaypointIndexByNumber()` to locate the home waypoint in the waypoint_configs list by its waypoint number.

### Time Tracking
- `home_start_time`: Unix timestamp when Rose arrives at home
- `at_home`: Boolean flag indicating if currently at home
- `loop_started`: Boolean flag indicating if patrol loop has begun

### Timer Management
When at home, timer is set to remaining duration:
```lsl
integer remaining = (HOME_DURATION_MINUTES - elapsed_minutes) * 60;
llSetTimerEvent((float)remaining);
```

This allows interruption for interactions without losing track of home time.

## See Also

- `WAYPOINT_CONFIGURATION_GUIDE.md` - Complete waypoint setup guide
- `RoseConfig.txt` - Main configuration file
- `[WPP]WaypointConfig.notecard` - Waypoint definitions
