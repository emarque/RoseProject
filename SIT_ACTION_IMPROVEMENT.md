# Sit Action Improvement

## Problem

The sit waypoint action was not working properly:
- It would play a sit animation
- But Rose wouldn't actually sit on anything
- She would just stand in place with a sit animation

## Requirements

User specified:
> "The sit waypoint action needs improvement- the character should look for the closest prim labelled "sit" and sit on that, playing the specified animation."

## Solution

Implemented a comprehensive sit system that:
1. Searches for nearby prims with "sit" in their name
2. Finds the closest matching prim
3. Requests permissions to sit
4. Actually sits on the prim using LSL's `llSit()` function
5. Plays the specified animation while sitting
6. Properly unsits when activity completes

## Implementation

### New State Variables

**Lines 73-76 in [WPP]WPManager.lsl**:
```lsl
// Sit target finding
key sit_target_key = NULL_KEY;
integer sit_permissions_granted = FALSE;
integer waiting_for_sit_sensor = FALSE;
```

### Enhanced Sit Action Handler

**Lines 497-511 in processWaypoint()**:
```lsl
else if (activity_type == "sit")
{
    llOwnerSay("Activity: " + current_activity_name + " (" + (string)activity_duration + "s)");
    
    // Find closest prim labeled "sit"
    waiting_for_sit_sensor = TRUE;
    llSensorRepeat("", NULL_KEY, PASSIVE|ACTIVE, 10.0, PI, 1.0);
    
    // Play animation if specified
    if (activity_animation != "")
    {
        llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
    }
    
    updateState("SITTING");
    
    if (activity_duration > 0)
    {
        llSetTimerEvent((float)activity_duration);
    }
}
```

### Sensor Event Handler

**Lines 926-962**:
```lsl
sensor(integer num)
{
    if (!waiting_for_sit_sensor) return;
    
    // Find closest prim with "sit" in its name
    integer i;
    float closest_distance = 999.0;
    key closest_key = NULL_KEY;
    
    for (i = 0; i < num; i++)
    {
        string name = llToLower(llDetectedName(i));
        if (llSubStringIndex(name, "sit") != -1)
        {
            float distance = llVecDist(llGetPos(), llDetectedPos(i));
            if (distance < closest_distance)
            {
                closest_distance = distance;
                closest_key = llDetectedKey(i);
            }
        }
    }
    
    if (closest_key != NULL_KEY)
    {
        sit_target_key = closest_key;
        llOwnerSay("Found sit target: " + llKey2Name(sit_target_key));
        
        // Request permissions to change links (needed for sitting)
        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION | PERMISSION_TAKE_CONTROLS);
    }
    else
    {
        llOwnerSay("No 'sit' prim found nearby");
    }
    
    waiting_for_sit_sensor = FALSE;
    llSensorRemove();
}
```

### No Sensor Handler

**Lines 964-971**:
```lsl
no_sensor()
{
    if (waiting_for_sit_sensor)
    {
        llOwnerSay("No 'sit' prim found nearby");
        waiting_for_sit_sensor = FALSE;
        llSensorRemove();
    }
}
```

### Permissions Handler

**Lines 973-984**:
```lsl
run_time_permissions(integer perms)
{
    if (perms & PERMISSION_TRIGGER_ANIMATION)
    {
        sit_permissions_granted = TRUE;
        
        // Now sit on the target
        if (sit_target_key != NULL_KEY)
        {
            llSit(sit_target_key);
            llOwnerSay("Sitting on target");
        }
    }
}
```

### Unsitting When Complete

**Added to timer() at lines 678 and 691**:
```lsl
// Unsit if we're sitting
if (current_state == "SITTING")
{
    llUnSit(llGetOwner());
    sit_target_key = NULL_KEY;
}
```

## How It Works

### Step-by-Step Flow

1. **Waypoint with Sit Action Reached**
   - `processWaypoint()` detects `activity_type == "sit"`
   - Sets `waiting_for_sit_sensor = TRUE`
   - Starts sensor with `llSensorRepeat()` (10m range, 1 second repeat)
   - Plays specified animation if any

2. **Sensor Finds Prims**
   - `sensor()` event fires with detected objects
   - Loops through all detected objects
   - Checks if name contains "sit" (case-insensitive)
   - Finds the closest matching prim

3. **Request Permissions**
   - Stores `sit_target_key` with closest prim's UUID
   - Calls `llRequestPermissions()` to get animation and control permissions
   - These permissions are needed for `llSit()` to work

4. **Actually Sit**
   - `run_time_permissions()` event fires when user grants permissions
   - Calls `llSit(sit_target_key)` to actually sit on the prim
   - Rose's avatar moves to and sits on the prim

5. **Activity Continues**
   - Rose remains seated for the specified duration
   - Specified animation plays during sitting
   - Timer tracks activity duration

6. **Activity Ends**
   - When duration reached or timeout occurs
   - Calls `llUnSit(llGetOwner())` to stand up
   - Clears `sit_target_key`
   - Moves to next waypoint

## Naming Convention

Prims should be named with "sit" in them (case-insensitive):
- ✅ "Sit Chair"
- ✅ "desk_sit"
- ✅ "Sitting Area"
- ✅ "CHAIR-SIT-01"
- ❌ "Chair" (no "sit" in name)
- ❌ "Desk" (no "sit" in name)

## Configuration Example

In `[WPP]WaypointConfig.notecard`:
```
WAYPOINT0=<128.5, 128.5, 21.0>|{"type":"sit","name":"Desk work","orientation":90,"time":300,"animation":"anim sit working"}
```

This will:
1. Navigate to position (128.5, 128.5, 21.0)
2. Find closest prim with "sit" in name
3. Sit on that prim
4. Play "anim sit working" animation
5. Stay seated for 300 seconds (5 minutes)
6. Stand up and move to next waypoint

## Range and Timing

- **Sensor Range**: 10 meters (can be adjusted)
- **Sensor Repeat**: 1 second (finds target quickly)
- **Sensor Arc**: PI (180 degrees, full forward hemisphere)
- **Sensor Types**: PASSIVE | ACTIVE (finds all object types)

## Error Handling

If no "sit" prim is found:
- Message: "No 'sit' prim found nearby"
- Rose stays standing at the waypoint
- Animation still plays if specified
- Activity continues normally

## Files Changed

- `RoseReceptionist.LSL/[WPP]WPManager.lsl`
  - Added sit target variables
  - Enhanced sit action handler
  - Added sensor/no_sensor events
  - Added run_time_permissions event
  - Added unsitting on completion

## Testing

### Setup
1. Create a prim named "Sit Chair" near waypoint
2. Configure waypoint with `"type":"sit"`
3. Add animation name if desired

### Expected Behavior
```
[2:30:00 PM] Rose_v5: Activity: Desk work (300s)
[2:30:01 PM] Rose_v5: Found sit target: Sit Chair
[2:30:01 PM] Rose_v5: Sitting on target
(Rose's avatar moves to and sits on chair)
[2:35:00 PM] Rose_v5: Activity done: Desk work
(Rose stands up and moves to next waypoint)
```

## Benefits

1. ✅ More realistic behavior (actually sits on furniture)
2. ✅ Flexible - works with any prim named with "sit"
3. ✅ Robust - handles missing prims gracefully
4. ✅ Automatic - finds and sits without manual positioning
5. ✅ Clean - properly unsits when done
