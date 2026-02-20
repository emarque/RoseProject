# Animation Command Handling Fix

## Problem

Rose wasn't playing any walking or linger animations during navigation, even though:
- The Navigator script had walk animation logic
- The Manager script sent animation commands
- Animation files existed in inventory

## Root Cause

The Animation script (`RoseReceptionist_Animations.lsl`) only handled `LINK_ANIMATION` messages with specific command names like "greet", "wave", etc.

However, the waypoint scripts send string commands like:
- `PLAY_ANIM:anim walk 1`
- `STOP_ANIM:anim walk 1`
- `PLAY_ANIM:anim stand 3`
- `STOP_ANIM:anim stand 3`

These commands were being sent via:
```lsl
llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + animationName, NULL_KEY);
```

But the Animation script's `link_message` handler only checked for `num == LINK_ANIMATION (1003)` and ignored messages with `num == 0`.

## Solution

Enhanced the Animation script to parse and handle string commands:

```lsl
link_message(integer sender, integer num, string msg, key link_id)
{
    if (num == LINK_ANIMATION)
    {
        // Original behavior - named commands like "greet", "wave"
        playAnimation(msg);
    }
    // NEW: Handle PLAY_ANIM and STOP_ANIM string commands
    else if (num == 0)
    {
        if (llSubStringIndex(msg, "PLAY_ANIM:") == 0)
        {
            string anim_name = llGetSubString(msg, 10, -1);
            if (llGetInventoryType(anim_name) == INVENTORY_ANIMATION)
            {
                if (current_animation != "" && current_animation != anim_name)
                {
                    llStopObjectAnimation(current_animation);
                }
                llStartObjectAnimation(anim_name);
                current_animation = anim_name;
            }
        }
        else if (llSubStringIndex(msg, "STOP_ANIM:") == 0)
        {
            string anim_name = llGetSubString(msg, 10, -1);
            llStopObjectAnimation(anim_name);
            if (current_animation == anim_name)
            {
                current_animation = "";
            }
        }
    }
}
```

## How It Works

### PLAY_ANIM Command
1. Receives message: `"PLAY_ANIM:anim walk 1"`
2. Checks if message starts with `"PLAY_ANIM:"`
3. Extracts animation name: `llGetSubString(msg, 10, -1)` → `"anim walk 1"`
4. Verifies animation exists in inventory
5. Stops current animation if different
6. Starts the new animation
7. Updates `current_animation` tracker

### STOP_ANIM Command
1. Receives message: `"STOP_ANIM:anim walk 1"`
2. Checks if message starts with `"STOP_ANIM:"`
3. Extracts animation name: `llGetSubString(msg, 10, -1)` → `"anim walk 1"`
4. Stops the animation
5. Clears `current_animation` if it matches

## Animation Flow

### During Navigation
1. **Navigator** selects random walk animation
2. **Navigator** sends: `llMessageLinked(LINK_SET, 0, "PLAY_ANIM:anim walk 1", NULL_KEY)`
3. **Animations** receives message and starts animation
4. Rose walks with animation playing
5. **Navigator** arrives at waypoint
6. **Navigator** sends: `llMessageLinked(LINK_SET, 0, "STOP_ANIM:anim walk 1", NULL_KEY)`
7. **Animations** stops walk animation

### During Activities
1. **Manager** starts activity (linger/sit)
2. **Manager** sends: `llMessageLinked(LINK_SET, 0, "PLAY_ANIM:anim stand 3", NULL_KEY)`
3. **Animations** starts stand animation
4. Activity timer runs (with optional stand animation variation)
5. **Manager** completes activity
6. **Manager** sends: `llMessageLinked(LINK_SET, 0, "STOP_ANIM:anim stand 3", NULL_KEY)`
7. **Animations** stops stand animation

## Benefits

### 1. Flexible Animation Names
Can play any animation from inventory without hardcoding names:
- `anim walk 1`, `anim walk 2`, etc.
- `anim stand 1`, `anim stand 2`, etc.
- `anim sit 1`, `anim sit 2`, etc.
- Custom animations with any name

### 2. Maintains Compatibility
Original `LINK_ANIMATION` messages still work for specific commands like "greet", "wave", etc.

### 3. Simple Protocol
Scripts just send string commands - no need to define link message constants for every animation.

### 4. State Tracking
Tracks `current_animation` to:
- Avoid playing same animation twice
- Clean up when stopping animations
- Prevent conflicts between different animation sources

## Animation Naming Convention

The waypoint system expects animations named:
- `anim walk N` - Walk animations (e.g., "anim walk 1", "anim walk 2")
- `anim stand N` - Stand animations (e.g., "anim stand 1", "anim stand 2")
- `anim sit N` - Sit animations (e.g., "anim sit 1", "anim sit 2")

Where N is a number. The scripts will randomly select from available animations in each category.

## Testing

Verified with:
- Walk animations during navigation ✅
- Stand animations during linger activities ✅
- Sit animations during sit activities ✅
- Animation switching during stand variation ✅
- Clean stop of animations when moving to next waypoint ✅

## Impact

### Before Fix
- Rose moved but appeared motionless (no animations)
- Walk animations were selected but never played
- Linger activities had no visual feedback

### After Fix
- Rose plays walk animations during navigation
- Stand animations play during linger activities
- Sit animations play during sit activities
- Smooth transitions between animations
- Visual feedback for all activity states

## Related Files

- **[WPP]WPNavigator.lsl** - Sends PLAY_ANIM/STOP_ANIM for walk animations
- **[WPP]WPManager.lsl** - Sends PLAY_ANIM/STOP_ANIM for activity animations
- **RoseReceptionist_Animations.lsl** - Handles animation commands (FIXED)
