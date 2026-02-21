# Link Message Collision Fix

## Problem Description

The Training script and Waypoint navigation system were using overlapping link message integers, causing messages to be misinterpreted by the wrong scripts.

### Collision Details

**Training System** (RoseReceptionist_Training.lsl, RoseReceptionist_Main.lsl):
```lsl
integer LINK_TRAINING_START = 3000;
integer LINK_TRAINING_COMPLETE = 3001;
integer LINK_TRAINING_ACTIVE = 3002;
integer LINK_TRAINING_CANCEL = 3003;
```

**Waypoint Navigation** ([WPP]WPManager.lsl, [WPP]WPNavigator.lsl):
```lsl
integer LINK_NAV_GOTO = 3000;      // COLLISION!
integer LINK_NAV_ARRIVED = 3001;   // COLLISION!
integer LINK_NAV_TIMEOUT = 3002;   // COLLISION!
```

### Symptoms

User reported seeing messages like:
```
⚠️ <9.97592, 10.97975, 39.96180> attempted to access training mode but was not authorized.
```

This happened because:
1. WPManager sent `LINK_NAV_GOTO (3000)` message with position vector
2. Training script also listened for `LINK_TRAINING_START (3000)`
3. Training script interpreted the navigation message as a training request
4. Training script tried to check if the position vector was an authorized trainer
5. Obviously failed and showed error with vector as "user name"

## Solution

Moved waypoint navigation link messages to a new range: 4000-4002

### Changes Made

**[WPP]WPManager.lsl** (lines 8-10):
```lsl
// OLD:
integer LINK_NAV_GOTO = 3000;
integer LINK_NAV_ARRIVED = 3001;
integer LINK_NAV_TIMEOUT = 3002;

// NEW:
integer LINK_NAV_GOTO = 4000;
integer LINK_NAV_ARRIVED = 4001;
integer LINK_NAV_TIMEOUT = 4002;
```

**[WPP]WPNavigator.lsl** (lines 10-12):
```lsl
// Same changes as above
```

## Link Message Integer Allocation

Current allocation across all scripts:

| Range | Constant | Purpose | Scripts |
|-------|----------|---------|---------|
| **1000-1004** | Core Functions | | |
| 1000 | LINK_SENSOR_DETECTED | Sensor detected avatar | Sensor, Main |
| 1001 | LINK_CHAT_MESSAGE | Chat message from avatar | Chat, Main |
| 1002 | LINK_SPEAK | Speak text | Main, Chat |
| 1003 | LINK_ANIMATION | Play animation | Main, Animations |
| 1004 | LINK_HTTP_REQUEST | HTTP request | Main |
| **2000-2002** | Wandering State | | |
| 2000 | LINK_WANDERING_STATE | State changes (GREETING, CHATTING, IDLE) | Multiple |
| 2001 | LINK_ACTIVITY_UPDATE | Current activity name | Manager, Main |
| 2002 | LINK_ACTION_EXECUTE | Execute action from chat | Main |
| **3000-3003** | Training System | | |
| 3000 | LINK_TRAINING_START | Start training mode | Main, Training |
| 3001 | LINK_TRAINING_COMPLETE | Training completed | Main, Training |
| 3002 | LINK_TRAINING_ACTIVE | Training mode active | Main, Training |
| 3003 | LINK_TRAINING_CANCEL | Training cancelled | Main, Training |
| **3010-3012** | Activity Reporting | | |
| 3010 | LINK_ACTIVITY_START | Activity started | Manager, Reporter |
| 3011 | LINK_ACTIVITY_COMPLETE | Activity completed | Manager, Reporter |
| 3012 | LINK_ACTIVITY_QUERY | Query current activity | Reporter |
| **4000-4002** | Navigation | | |
| 4000 | LINK_NAV_GOTO | Navigate to position | Manager, Navigator |
| 4001 | LINK_NAV_ARRIVED | Arrived at waypoint | Navigator, Manager |
| 4002 | LINK_NAV_TIMEOUT | Navigation timeout | Navigator, Manager |

## Testing

### Verification Steps

1. **Before Fix**: Navigation triggered spurious training messages
   ```
   [21:30] Rose_v4: ⚠️ <9.97592, 10.97975, 39.96180> attempted to access training mode
   ```

2. **After Fix**: Clean navigation with no training messages
   ```
   [21:35] Rose_v4: 20 waypoints (list len=160)
   [21:35] Rose_v4: Activity: Water plants (30s)
   ```

3. **Training Still Works**: Training mode activation unaffected by navigation
   - Training uses 3000-3003 range
   - Navigation uses 4000-4002 range
   - No overlap, no interference

## Prevention Guidelines

### For Future Development

1. **Document All Link Messages**: Maintain the allocation table above
2. **Use Unique Ranges**: Each system should have its own 10-integer range
3. **Check Before Adding**: Always verify new link message integers don't conflict
4. **Use Descriptive Names**: Make purpose clear in constant names
5. **Group Related Messages**: Keep related messages in consecutive integers

### Recommended Ranges for Future Systems

Available ranges for new features:
- 1010-1019: Available for core function expansion
- 2010-2019: Available for state management expansion
- 4010-4019: Available for navigation expansion
- 5000-5999: Available for new major systems

## Related Issues

This fix also resolved:
- Walk animation issues (Navigator now properly coordinates with Animation script)
- HTML entity decoding in waypoints
- Case-sensitive waypoint matching

## Impact

✅ Clean script communication  
✅ No spurious error messages  
✅ Training system works independently  
✅ Navigation system works independently  
✅ Room for future expansion
