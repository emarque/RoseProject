# Animation Cycling Feature

## Overview

The animation cycling feature allows waypoints to specify multiple animations that cycle automatically during an activity. Instead of playing a single animation for the entire duration, Rose can now alternate between multiple animations, creating more dynamic and natural-looking behavior.

## Configuration Format

### Animations Array

Use the `animations` field with an array of animation names:

```json
{
  "type": "linger",
  "name": "dancing",
  "time": 300,
  "animations": ["anim dance 1", "anim dance 2", "anim dance 3"],
  "animInterval": 45
}
```

### AnimInterval

The `animInterval` field controls how often animations change (in seconds):

- **Default**: 30 seconds if not specified
- **Minimum**: Any positive value
- **Typical Range**: 10-120 seconds

```json
"animInterval": 45  // Changes animation every 45 seconds
```

## How It Works

### Cycling Behavior

1. **Start**: First animation from the list begins
2. **Timer**: After `animInterval` seconds, stop current animation
3. **Next**: Start next animation in the list
4. **Loop**: After last animation, return to first
5. **Complete**: When activity duration ends, stop current animation

### Timing Example

Activity with 5-minute duration and 3 animations with 45-second interval:

```
0:00 - Start "anim dance 1"
0:45 - Switch to "anim dance 2"
1:30 - Switch to "anim dance 3"
2:15 - Loop back to "anim dance 1"
3:00 - Switch to "anim dance 2"
3:45 - Switch to "anim dance 3"
4:30 - Switch to "anim dance 1"
5:00 - Activity complete, stop animation
```

## Usage Examples

### 1. Dancing (3 dances, 45s intervals)

```json
WAYPOINT4={"type":"linger","name":"dancing","time":300,"animations":["anim dance 1","anim dance 2","anim dance 3"],"animInterval":45}
```

**Behavior**: Cycles through 3 different dance animations, changing every 45 seconds during 5-minute dance session.

### 2. Exercise Routine (default 30s)

```json
WAYPOINT5={"type":"linger","name":"exercising","time":180,"animations":["anim stretch","anim jumping jacks","anim yoga"]}
```

**Behavior**: 3-minute exercise routine alternating between stretching, jumping jacks, and yoga every 30 seconds (default).

### 3. Social Chatting (60s intervals)

```json
WAYPOINT1={"type":"linger","name":"chatting","time":300,"animations":["friendly_talk","laugh","gesture"],"animInterval":60}
```

**Behavior**: 5-minute conversation with animated gestures changing every minute.

### 4. Teaching Class (90s intervals)

```json
WAYPOINT6={"type":"linger","name":"teaching","time":540,"animations":["pointing","writing board","explaining","gesturing"],"animInterval":90}
```

**Behavior**: 9-minute teaching session with 4 different teaching poses, each lasting 90 seconds.

### 5. Meditation (slow changes, 120s)

```json
WAYPOINT7={"type":"linger","name":"meditating","time":600,"animations":["lotus pose","standing meditation","seated meditation"],"animInterval":120}
```

**Behavior**: 10-minute meditation with 3 poses, changing every 2 minutes for smooth transitions.

### 6. Performance Art (quick changes, 20s)

```json
WAYPOINT8={"type":"linger","name":"performing","time":240,"animations":["pose 1","pose 2","pose 3","pose 4","pose 5"],"animInterval":20}
```

**Behavior**: 4-minute performance with 5 dynamic poses, rapidly changing every 20 seconds.

### 7. Quick Transitions (10s)

```json
WAYPOINT9={"type":"linger","name":"fidgeting","time":60,"animations":["stand idle 1","stand idle 2"],"animInterval":10}
```

**Behavior**: 1-minute wait with subtle animation changes every 10 seconds for natural fidgeting.

### 8. Backward Compatible (single animation)

```json
WAYPOINT10={"type":"linger","name":"working","time":120,"animation":"typing"}
```

**Behavior**: Works exactly as before - single animation plays for entire 2-minute duration.

## Technical Implementation

### New Variables

```lsl
list activity_animations = [];           // List of animations to cycle through
integer activity_anim_interval = 30;     // Seconds between animation changes
integer current_anim_index = 0;          // Current position in animations list
integer last_anim_change_time = 0;       // Timestamp of last animation change
```

### Parsing Logic (parseWaypointJSON)

1. Check for `"animations":[...]` array first (new format)
2. Fall back to `"animation":"..."` string (backward compatibility)
3. Parse `"animInterval":value` with default of 30 seconds
4. Return expanded format: `[type, name, orientation, time, animationsStr, animInterval, attachJson]`

### Helper Function (parseAnimationsList)

Converts comma-separated animation string into list:
- Handles JSON array format: `"anim1","anim2","anim3"`
- Removes quotes and trims whitespace
- Returns empty list if no animations
- Supports single animation (converted to 1-item list)

### Cycling Logic (timer)

```lsl
if (llGetListLength(activity_animations) > 1 && activity_anim_interval > 0)
{
    integer time_since_anim_change = llGetUnixTime() - last_anim_change_time;
    if (time_since_anim_change >= activity_anim_interval)
    {
        // Stop current animation
        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
        
        // Move to next animation (loops back to 0 after last)
        current_anim_index = (current_anim_index + 1) % llGetListLength(activity_animations);
        activity_animation = llList2String(activity_animations, current_anim_index);
        last_anim_change_time = llGetUnixTime();
        
        // Start new animation
        llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
    }
}
```

### Activity Processing (processWaypoint)

When activity starts:
1. Parse animations string into list
2. Set first animation as current
3. Reset animation index to 0
4. Record start time for cycling

## Backward Compatibility

### Old Format Still Works

Single animation field continues to work:
```json
"animation": "typing"
```

Internally converted to:
```lsl
activity_animations = ["typing"];
current_anim_index = 0;
```

### Detection Logic

- If `animations` array found → Use new format
- If only `animation` string found → Convert to 1-item list
- If neither found → Empty list (use stand animations)

### No Migration Needed

Existing waypoint configs work without any changes. The new format is purely additive.

## Troubleshooting

### Problem: Animations Don't Cycle

**Possible Causes**:
1. Only one animation in the list
2. `animInterval` set to 0 or very large value
3. Activity duration shorter than `animInterval`
4. Animations not in inventory

**Solutions**:
- Verify animations array has multiple entries
- Check `animInterval` is reasonable (30-60 seconds typical)
- Ensure activity duration > `animInterval`
- Confirm all animation names exist in inventory

### Problem: Animation Changes Too Fast/Slow

**Solution**: Adjust `animInterval` value:
- Too fast: Increase interval (e.g., 60 or 90 seconds)
- Too slow: Decrease interval (e.g., 15 or 20 seconds)

### Problem: Animation Stuck on First

**Possible Causes**:
1. Timer not firing
2. State not set to LINGERING or SITTING
3. Logic condition not met

**Check**:
- Activity type is "linger" or "sit"
- Multiple animations in list
- animInterval > 0

### Problem: Wrong Animation Playing

**Possible Causes**:
1. Animation name mismatch with inventory
2. Quotes or spaces in animation name
3. Case sensitivity

**Solutions**:
- Verify exact animation names in inventory
- Check for extra quotes or spaces
- Names are case-sensitive in SL

## Best Practices

### Animation Selection

1. **Similar Energy**: Choose animations with similar energy levels
   - Don't mix: calm meditation + energetic dance
   - Do mix: gentle stretches + standing meditation

2. **Smooth Transitions**: Consider how animations flow together
   - Avoid jarring pose changes
   - Test animation pairs for natural flow

3. **Timing**: Match interval to animation length
   - Short loops: 10-20 second intervals
   - Long animations: 45-90 second intervals

### Interval Guidelines

| Activity Type | Recommended Interval | Reasoning |
|---------------|---------------------|-----------|
| Dancing | 30-60 seconds | Natural song changes |
| Exercise | 20-40 seconds | Exercise set duration |
| Social | 45-90 seconds | Conversation flow |
| Teaching | 60-120 seconds | Explanation segments |
| Meditation | 90-180 seconds | Deep relaxation phases |
| Performance | 15-30 seconds | Dynamic variety |
| Idle Waiting | 5-15 seconds | Subtle fidgeting |

### Performance Considerations

1. **Animation Count**: 2-5 animations ideal
   - Too few: Limited variety
   - Too many: Confusing, high memory

2. **Interval**: Don't go below 5 seconds
   - Prevents rapid switching
   - Gives animations time to be seen

3. **Duration**: Ensure activity duration allows cycling
   - Minimum: 2× `animInterval` to see 2 animations
   - Optimal: 4-5× `animInterval` for full variety

### Memory Efficiency

- Animation names stored as strings in list
- Typical impact: ~50-200 bytes per waypoint
- Negligible compared to notecard and config storage
- No performance impact during execution

## Related Features

### Stand Animation Variation

Different from animation cycling:
- **Stand Variation**: Used when NO specific animation specified
- **Animation Cycling**: Used when multiple animations specified
- Both can be active in different waypoints

### Sit Action with Animations

Cycling works with sit actions too:
```json
{"type":"sit","name":"relaxing","time":600,"animations":["sit idle 1","sit idle 2","sit stretch"],"animInterval":90}
```

Rose will cycle through sitting animations while seated on the sit target.

### Schedule-Based Activities

Animation cycling works across all schedules:
- Work waypoints can use cycling
- After-work waypoints can use cycling
- Night waypoints can use cycling

Each schedule period can have different animation sets and intervals.

## Summary

**Key Benefits**:
- ✅ More dynamic and interesting activities
- ✅ Natural variety in long-duration actions
- ✅ Fully configurable timing
- ✅ Automatic looping
- ✅ Backward compatible
- ✅ Low memory overhead
- ✅ Easy to configure

**Usage**: Add `animations` array and optional `animInterval` to any linger or sit waypoint configuration.

**Testing**: Try with 2-3 animations first, adjust interval based on activity type and animation lengths.
