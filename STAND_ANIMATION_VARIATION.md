# Stand Animation Variation Feature

## Problem

Rose was getting stuck frequently during activities. The animation would end but she wouldn't continue through her activity loop. Additionally, when performing activities without specific animations, she would play the same stand animation for the entire duration, which looked unnatural.

## Solution

Implemented a stand animation variation system that:

1. **Prevents getting stuck**: The timer now properly checks elapsed time during LINGERING state and moves to the next waypoint when the activity duration is complete
2. **Varies stand animations**: When no specific animation is assigned to an activity, Rose randomly switches between available stand animations at a configurable interval
3. **Configuration parameter**: Added `STAND_ANIMATION_INTERVAL` to control how often stand animations change (default: 5 seconds)

## Configuration

### RoseConfig.txt

```
# Stand Animation Variation
# How often (in seconds) to switch to a random stand animation during activities
# Set to 0 to disable automatic variation (default: 5)
STAND_ANIMATION_INTERVAL=5
```

### Script Variables

```lsl
// Configuration
integer STAND_ANIMATION_INTERVAL = 5;  // seconds between stand animation changes

// State tracking
string current_stand_animation = "";  // Currently playing stand animation
integer last_stand_change_time = 0;   // When stand animation was last changed
```

## Implementation Details

### New Helper Functions

#### switchStandAnimation()
- Stops the current stand animation if one is playing
- Randomly selects a new stand animation from available_stand_animations
- Plays the new animation via link message
- Records the time of the change

#### stopStandAnimation()
- Stops the current stand animation if one is playing
- Clears the current_stand_animation state

### Modified Functions

#### processWaypoint() - Linger Activity Handling

**Before:**
```lsl
if (activity_animation != "")
{
    llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
}
else 
{
    // Pick a random stand animation once
    integer numAnims = llGetListLength(available_stand_animations);
    integer randIndex = (integer)llFrand(numAnims);
    llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + llList2String(available_stand_animations, randIndex), NULL_KEY);
}

// Wait for duration
llSetTimerEvent((float)activity_duration);
current_state = "LINGERING";
```

**After:**
```lsl
if (activity_animation != "")
{
    llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
    // Store that we're using a specific animation (not a varying stand animation)
    current_stand_animation = "";
}
else 
{
    // Use varying stand animations
    switchStandAnimation();
}

// Set timer to check frequently for stand animation changes and activity completion
// Use the smaller of the two intervals
float timer_interval = (float)STAND_ANIMATION_INTERVAL;
if (activity_duration < STAND_ANIMATION_INTERVAL)
{
    timer_interval = (float)activity_duration;
}
llSetTimerEvent(timer_interval);
current_state = "LINGERING";
```

#### timer() - LINGERING State Handling

**Before:**
```lsl
else if (current_state == "LINGERING" || current_state == "SITTING")
{
    // Duration completed
    
    // Stop animation
    if (activity_animation != "")
    {
        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
    }
    
    moveToNextWaypoint();
}
```

**After:**
```lsl
else if (current_state == "LINGERING" || current_state == "SITTING")
{
    // Check if activity duration is complete
    integer elapsed = llGetUnixTime() - activity_start_time;
    
    if (elapsed >= activity_duration)
    {
        // Duration completed - stop animations and move to next waypoint
        
        // Stop animation
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
        }
        else
        {
            // Stop stand animation if we were using one
            stopStandAnimation();
        }
        
        moveToNextWaypoint();
    }
    else if (current_state == "LINGERING" && activity_animation == "" && current_stand_animation != "")
    {
        // We're lingering with stand animations - check if it's time to switch
        integer time_since_change = llGetUnixTime() - last_stand_change_time;
        if (time_since_change >= STAND_ANIMATION_INTERVAL)
        {
            switchStandAnimation();
        }
        
        // Set timer for next check
        integer time_until_duration = activity_duration - elapsed;
        float timer_interval = (float)STAND_ANIMATION_INTERVAL;
        if (time_until_duration < STAND_ANIMATION_INTERVAL)
        {
            timer_interval = (float)time_until_duration;
        }
        llSetTimerEvent(timer_interval);
    }
}
```

## Behavior

### Activities with Specific Animations

When an activity has a specific animation configured:
- The specified animation plays for the entire duration
- No stand animation variation occurs
- Timer is set to the animation interval for checking
- Animation stops when activity duration completes

### Activities without Specific Animations

When an activity has no specific animation (uses stand animations):
1. Initial stand animation is randomly selected and played
2. Timer is set to the smaller of: stand animation interval or remaining activity time
3. On each timer event:
   - Check if activity duration is complete → move to next waypoint
   - If not complete and it's time to change → switch to new random stand animation
   - Reset timer for next check
4. When activity completes, stop the current stand animation

## Example Timeline

For a 30-second activity with 5-second animation interval:

```
0s:  Activity starts, play random stand animation A
5s:  Timer fires, switch to random stand animation B
10s: Timer fires, switch to random stand animation C
15s: Timer fires, switch to random stand animation D
20s: Timer fires, switch to random stand animation E
25s: Timer fires, switch to random stand animation F
30s: Timer fires, activity complete, stop animation, move to next waypoint
```

## Benefits

1. **Prevents getting stuck**: Explicit elapsed time checking ensures activities complete properly
2. **More natural appearance**: Varying stand animations make Rose look more alive and less robotic
3. **Configurable**: Users can adjust the variation interval or disable it entirely
4. **Efficient**: Timer interval adapts based on remaining time to avoid unnecessary checks
5. **Compatible**: Works with existing animation system and specific activity animations

## Testing Recommendations

1. Test with activities of various durations (< 5s, = 5s, > 5s)
2. Test with activities that have specific animations
3. Test with activities that use stand animations
4. Verify timer resets properly between activities
5. Verify animations stop cleanly when moving to next waypoint
6. Test with different STAND_ANIMATION_INTERVAL values
7. Test with STAND_ANIMATION_INTERVAL=0 to disable variation

## Configuration Reading

The parameter is read from RoseConfig notecard in the dataserver event:

```lsl
else if (configKey == "STAND_ANIMATION_INTERVAL")
{
    STAND_ANIMATION_INTERVAL = (integer)value;
}
```

## Files Modified

1. **RoseReceptionist_GoWander3.lsl**
   - Added configuration variable
   - Added state tracking variables
   - Added helper functions
   - Modified processWaypoint() linger handling
   - Modified timer() LINGERING state handling
   - Added configuration reading

2. **RoseConfig.txt**
   - Added STAND_ANIMATION_INTERVAL parameter with documentation
