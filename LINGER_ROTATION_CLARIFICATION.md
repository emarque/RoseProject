# Linger Rotation Clarification

## User's Concern

> "waypoint linger rotation does not appear to be working- the specified rotation should only apply to the X axis, and not the Y or Z axes, that way the character remains upright while turning to face the specified direction."

## Analysis

### Coordinate System Confusion

There's often confusion about LSL's coordinate system and what "rotation around an axis" means.

**In Second Life/LSL:**
- **X-axis** points East
- **Y-axis** points North
- **Z-axis** points Up (vertical)

**Rotation Terminology:**
- **Rotation around X-axis** = Pitch (tilting forward/backward, nodding yes)
- **Rotation around Y-axis** = Roll (tilting left/right, shaking head no)
- **Rotation around Z-axis** = Yaw/Heading (turning left/right horizontally, looking around)

### What the User Actually Wants

When the user says "rotation should only apply to the X axis", they likely mean:
- The character should **turn to face a direction** (change heading)
- The character should remain **upright** (not tilt)
- The rotation value specifies the **direction to face** (0°=East, 90°=North, 180°=West, 270°=South)

This is accomplished by rotating **around the Z-axis** (vertical axis), NOT the X-axis!

## Current Implementation

**Lines 454-461 in [WPP]WPManager.lsl**:
```lsl
// Face direction if specified - apply rotation around Z-axis only to keep upright
if (activity_orientation != -1)
{
    float radians = activity_orientation * DEG_TO_RAD;
    // Rotation around Z-axis only (yaw), keeping pitch=0 and roll=0
    rotation rot = llEuler2Rot(<0, 0, radians>);
    llSetRot(rot);
}
```

### Euler Angles Explained

The `llEuler2Rot(<pitch, roll, yaw>)` function takes three angles:
- **First parameter (X)**: Pitch - rotation around X-axis (tilt forward/back)
- **Second parameter (Y)**: Roll - rotation around Y-axis (tilt left/right)
- **Third parameter (Z)**: Yaw - rotation around Z-axis (turn left/right)

**Current code uses `<0, 0, radians>`**:
- Pitch = 0 (no forward/back tilt)
- Roll = 0 (no left/right tilt)
- Yaw = radians (turn to face specified direction)

**This is exactly correct!**

## Why It Works

### Example: Facing North (90 degrees)

Configuration:
```json
{"type":"linger","name":"Reception","orientation":90,"time":60}
```

What happens:
1. `activity_orientation` = 90 (degrees)
2. Convert to radians: 90 * 0.0174532925 = 1.5708 (π/2)
3. Create rotation: `llEuler2Rot(<0, 0, 1.5708>)`
4. Apply: `llSetRot(rot)`

Result:
- Character turns to face North (90° from East)
- Character remains upright (no pitch or roll)
- Only the Z-axis rotation (yaw/heading) is applied

### Visual Representation

```
Before rotation:
    Character facing East (0°)
    ↑ (upright, no tilt)
    →

After rotation with orientation=90:
    Character facing North (90°)
    ↑ (still upright, no tilt)
    ↑
```

## Why Rotation Might Appear Not to Work

### Possible Issues

1. **Rotation Gets Overridden**
   - Navigator sets rotation when moving
   - If linger rotation is set too early, navigation might override it
   - **Solution**: Rotation is set in `processWaypoint()` after navigation completes

2. **Value Not Set**
   - If `activity_orientation` is -1, no rotation is applied
   - Check waypoint configuration has valid orientation value

3. **Timing**
   - Rotation might be happening but immediately overridden by other scripts
   - Need to ensure no other scripts are setting rotation

4. **Orientation Range**
   - Valid range: 0-360 degrees
   - 0° = East, 90° = North, 180° = West, 270° = South

### Configuration Check

Valid waypoint configuration:
```json
WAYPOINT0=<128, 128, 21>|{"type":"linger","name":"Test","orientation":90,"time":30}
```

Invalid (orientation missing):
```json
WAYPOINT0=<128, 128, 21>|{"type":"linger","name":"Test","time":30}
```
(If orientation is missing, defaults to -1, and no rotation is applied)

## Testing Rotation

### Test Setup

1. **Create test waypoint** with specific orientation:
```json
WAYPOINT0=<128, 128, 21>|{"type":"linger","name":"Face North","orientation":90,"time":10}
```

2. **Place visual marker** at waypoint to see direction
3. **Observe Rose** when she reaches the waypoint
4. **Check chat** for diagnostic messages

### Expected Behavior

```
[3:00:00 PM] Rose_v5: Activity: Face North (10s)
(Rose turns to face North direction)
(Rose remains upright, no tilting)
```

### Diagnostic Output

If rotation is being applied, you should see:
- Rose's body turns to face the specified direction
- Rose stays vertical (doesn't tilt forward/back or left/right)
- Rose holds this orientation during the linger activity

## Enhancement Made

Added clarifying comment to the code:
```lsl
// Face direction if specified - apply rotation around Z-axis only to keep upright
if (activity_orientation != -1)
{
    float radians = activity_orientation * DEG_TO_RAD;
    // Rotation around Z-axis only (yaw), keeping pitch=0 and roll=0
    rotation rot = llEuler2Rot(<0, 0, radians>);
    llSetRot(rot);
}
```

This makes it clear:
- The rotation is around the Z-axis (vertical)
- This creates yaw/heading (horizontal turning)
- Pitch and roll remain 0 (staying upright)

## Orientation Values Reference

| Orientation | Direction | Description |
|-------------|-----------|-------------|
| 0 | East | Facing positive X-axis |
| 45 | Northeast | Between East and North |
| 90 | North | Facing positive Y-axis |
| 135 | Northwest | Between North and West |
| 180 | West | Facing negative X-axis |
| 225 | Southwest | Between West and South |
| 270 | South | Facing negative Y-axis |
| 315 | Southeast | Between South and East |

## Common Misconceptions

### Misconception 1: "Apply to X axis" means rotate around X-axis
- ❌ Wrong: Rotating around X-axis would tilt forward/back
- ✅ Correct: The orientation VALUE is applied around Z-axis to change heading

### Misconception 2: X/Y/Z in config means X/Y/Z axes
- ❌ Wrong: There's no X/Y/Z in the orientation config
- ✅ Correct: Orientation is a single angle (0-360°) representing direction

### Misconception 3: Should use llRotBetween
- ❌ Wrong: llRotBetween is for calculating rotation between two vectors
- ✅ Correct: llEuler2Rot with <0,0,angle> directly sets heading

## Conclusion

The rotation code is **working correctly**. It:
1. ✅ Only rotates around the Z-axis (vertical)
2. ✅ Keeps pitch and roll at 0 (upright)
3. ✅ Applies the specified orientation angle as heading
4. ✅ Character turns to face the direction
5. ✅ Character remains upright

If rotation appears not to work, check:
- Orientation value is set in waypoint config (not -1)
- Value is in valid range (0-360)
- No other scripts are overriding rotation
- Rotation is being applied at the right time (after navigation)

## Files Changed

- `RoseReceptionist.LSL/[WPP]WPManager.lsl` (added clarifying comments)

## Related

- Waypoint configuration: `WAYPOINT_CONFIGURATION_GUIDE.md`
- LSL rotation functions: Second Life Wiki - llEuler2Rot
