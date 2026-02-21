# Schedule-Based Activities - Quick Reference

## Quick Setup

1. **Update RoseConfig.txt** (already has defaults):
```ini
SHIFT_START_TIME=09:00
SHIFT_END_TIME=17:00
NIGHT_START_TIME=22:00
```

2. **Create After-Work Config** (`[WPP]AfterWorkConfig.notecard`):
```
WAYPOINT0={"type":"linger","name":"relaxing","time":300}
WAYPOINT1={"type":"transient","name":"heading home"}
```

3. **Create Night Config** (`[WPP]NightConfig.notecard`):
```
WAYPOINT0={"type":"transient","name":"going to bedroom"}
WAYPOINT1={"type":"sit","name":"sleeping","time":28800}
```

4. **Reset the script** - Done!

## Schedule Periods

| Period | Default Time | Config File | Purpose |
|--------|--------------|-------------|---------|
| WORK | 09:00-17:00 | [WPP]WaypointConfig | Receptionist duties |
| AFTER_WORK | 17:00-22:00 | [WPP]AfterWorkConfig | Personal time after work |
| NIGHT | 22:00-09:00 | [WPP]NightConfig | Home, sleep, morning routine |

## Messages

**Leaving Work** (17:00):
```
"Well everyone, my shift is over! I'll see you all tomorrow. Have a great evening!"
```

**Returning to Work** (09:00):
```
"Good morning everyone! I'm back at work."
```

**Schedule Transition**:
```
"⏰ Schedule transition: WORK → AFTER_WORK"
```

## Config File Format

All three config files use the same waypoint format:

```
# Simple transient waypoint
WAYPOINT0={"type":"transient","name":"hallway"}

# Linger with animation
WAYPOINT1={"type":"linger","name":"relaxing","time":300,"animation":"casual_stand"}

# Sit with long duration
WAYPOINT2={"type":"sit","name":"sleeping","time":28800,"animation":"sleep"}
```

## Common Configurations

### Office Hours (9-5)
```ini
SHIFT_START_TIME=09:00
SHIFT_END_TIME=17:00
NIGHT_START_TIME=22:00
```

### Extended Hours (8am-6pm)
```ini
SHIFT_START_TIME=08:00
SHIFT_END_TIME=18:00
NIGHT_START_TIME=22:00
```

### Early Shift (7am-3pm)
```ini
SHIFT_START_TIME=07:00
SHIFT_END_TIME=15:00
NIGHT_START_TIME=20:00
```

### Late Shift (1pm-9pm)
```ini
SHIFT_START_TIME=13:00
SHIFT_END_TIME=21:00
NIGHT_START_TIME=23:00
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not switching schedules | Check times are HH:MM format |
| 0 waypoints loaded | Create/populate config notecard |
| No announcement | Wait for actual transition time |
| Stuck in one period | Verify times don't overlap incorrectly |

## Testing

Test quickly by setting close times:
```ini
SHIFT_START_TIME=12:00
SHIFT_END_TIME=12:05
NIGHT_START_TIME=12:10
```

Reset script at 11:59, watch transitions at 12:00, 12:05, 12:10.

## Example Night Activities

```
# Walk to bedroom
WAYPOINT0={"type":"transient","name":"walking to bedroom"}

# Get ready for bed (3 min)
WAYPOINT1={"type":"linger","name":"getting ready","time":180}

# Sleep (8 hours = 28800 seconds)
WAYPOINT2={"type":"sit","name":"sleeping","time":28800,"animation":"sleep"}

# Morning routine (5 min)
WAYPOINT3={"type":"linger","name":"morning routine","time":300}

# Return to work
WAYPOINT4={"type":"transient","name":"heading to work"}
```

## Example After-Work Activities

```
# Relax in break room (5 min)
WAYPOINT0={"type":"linger","name":"relaxing","time":300,"attachments":[{"item":"Coffee Mug","point":"RightHand"}]}

# Chat with colleagues (3 min)
WAYPOINT1={"type":"linger","name":"chatting","time":180}

# Check personal messages (4 min)
WAYPOINT2={"type":"sit","name":"checking messages","time":240,"animation":"typing"}

# Tidy workspace (2 min)
WAYPOINT3={"type":"linger","name":"tidying up","time":120}
```

## Key Features

✅ Automatic schedule detection on startup
✅ Smooth transitions between periods
✅ Independent waypoint configs per period
✅ Configurable time ranges
✅ Natural chat announcements
✅ Handles midnight crossing
✅ Minimal performance overhead

## See Also

- Full documentation: `SCHEDULE_BASED_ACTIVITIES.md`
- Waypoint format guide: `WAYPOINT_CONFIGURATION_GUIDE.md`
- Main config reference: `RoseConfig.txt`
