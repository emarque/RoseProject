# Quick Reference: Training Wizard

## For Authorized Managers

### Starting Training Mode
```
1. Touch Rose
2. Select "Training Mode"
3. Choose mode if waypoints exist:
   - Replace All: Start fresh
   - Add New: Extend existing
```

### Configuring Each Waypoint

**Type Menu:**
- Transient → Pass through
- Linger → Stop and perform activity
- Sit → Sit down

**Duration Menu (Linger/Sit only):**
- 15s / 30s / 60s / 120s
- Custom (not yet implemented)
- Skip (uses 30s default)

**Animation Menu:**
- Lists animations from inventory
- None → No animation

**Orientation Menu:**
- North (90°) → Faces north
- East (0°) → Faces east  
- South (270°) → Faces south
- West (180°) → Faces west
- None → No rotation

**Attachments Menu:**
- (Coming soon)
- Done → Finish this waypoint

### After Training

**Output Format:**
```
WAYPOINT0={"type":"linger","name":"reception","orientation":0,"time":60,"animation":"wave","attachments":[]}
WAYPOINT1={"type":"transient","name":"hallway"}
```

**Replace All Mode:**
1. Copy all WAYPOINT lines from chat
2. Open `[WPP]WaypointConfig` notecard
3. Delete all existing WAYPOINT lines
4. Paste new lines
5. Save → Auto-reload

**Add New Mode:**
1. Copy all WAYPOINT lines from chat
2. Open `[WPP]WaypointConfig` notecard
3. Keep existing WAYPOINT lines
4. Paste new lines at end
5. Save → Auto-reload

## For Regular Users

### Getting Attention
```
1. Touch Rose
2. Select "Get Attention"
3. Rose waves and responds
```

### Requesting Training
- Touch Rose → Select "Training Mode"
- Message: "Sorry, I'm not authorized to take training from anyone but my managers..."
- Owner will be notified of your request

## Configuration Requirements

### RoseConfig Notecard

**For Authorization:**
```
# Add UUIDs of authorized trainers (replace with actual avatar UUIDs)
OWNER_UUID_1=00000000-0000-0000-0000-000000000000
OWNER_UUID_2=11111111-1111-1111-1111-111111111111

# Set receptionist name
RECEPTIONIST_NAME=Rose
```

### [WPP]WaypointConfig Notecard

**Format:**
```
# Comments start with #
WAYPOINT0={"type":"linger","name":"activity name","orientation":0,"time":60}
WAYPOINT1={"type":"transient","name":"passing through"}
```

## Waypoint Prim Naming

**Required Format:**
- Waypoint0
- Waypoint1  
- Waypoint2
- etc.

**Case insensitive:**
- Waypoint0 ✓
- waypoint0 ✓
- WAYPOINT0 ✓

**Spaces allowed:**
- "Waypoint 0" ✓ (trimmed automatically)

**Custom prefix** (in RoseConfig):
```
WAYPOINT_PREFIX=Checkpoint
```
Then use: Checkpoint0, Checkpoint1, etc.

## Orientation Guide

```
        North (90°)
             |
             |
West (180°)--+--East (0°)
             |
             |
        South (270°)
```

## Common Issues

### "No waypoints found"
- Check waypoint prim names
- Verify prims are within 50 meters
- Ensure prims are named sequentially from 0

### "Not authorized"
- User not in OWNER_UUID list
- Only owner and listed UUIDs can train
- Ask owner to add your UUID to RoseConfig

### "Training already active"
- Another user is in training mode
- Wait for them to finish or cancel
- Only one training session at a time

### Notecard not reloading
- Verify notecard name: `[WPP]WaypointConfig`
- Check for syntax errors in JSON
- Look for error messages in chat

## JSON Field Reference

**Required:**
- `type`: "transient" | "linger" | "sit"

**Optional:**
- `name`: Activity description (string)
- `orientation`: Direction in degrees (0-359)
- `time`: Duration in seconds (integer)
- `animation`: Animation name (string)
- `attachments`: Array of attachment objects

**Example (all fields):**
```json
{
  "type": "linger",
  "name": "watering plants",
  "orientation": 90,
  "time": 45,
  "animation": "watering",
  "attachments": [
    {"item": "Watering Can", "point": "RightHand"}
  ]
}
```

**Example (minimal):**
```json
{"type": "transient", "name": "hallway"}
```

## Tips

1. **Plan Your Route**: Place all waypoint prims before training
2. **Test Small**: Start with 2-3 waypoints, then expand
3. **Backup Config**: Copy notecard before making changes
4. **Use Comments**: Add # comments in notecard for clarity
5. **Sequential Numbers**: Ensure no gaps (0,1,2,3... not 0,1,3,5)
6. **Descriptive Names**: Use clear activity names for logging
7. **Test Navigation**: Verify waypoints are on navmesh
8. **Save Often**: Save notecard after each addition

## Quick Commands Reference

No chat commands - All interaction through touch menus.

## Error Messages

| Message | Meaning | Solution |
|---------|---------|----------|
| "Not authorized to take training" | User not in owner list | Add UUID to RoseConfig |
| "Training already active" | Another session running | Wait or reset scripts |
| "No waypoints found" | Prims not detected | Check naming and range |
| "Training cancelled" | Menu timeout or user cancel | Restart training mode |
| "Configuration updated, reloading" | Notecard changed | Normal - scripts reloading |

## Getting Help

1. Check `docs/WAYPOINT_SYSTEM.md` for full documentation
2. Review `WAYPOINT_REFACTOR_SUMMARY.md` for implementation details
3. Look at examples in `[WPP]WaypointConfig.notecard`
4. Check console for error messages
5. Verify all scripts are active and reset
