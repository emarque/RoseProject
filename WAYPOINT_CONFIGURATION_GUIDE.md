# Waypoint Configuration Setup Guide

## Problem: "0 waypoints configured"

If the script reports "0 waypoints configured" even though you have waypoints set up, the issue is that the `[WPP]WaypointConfig` notecard needs to be populated with actual waypoint data including position vectors.

## Understanding Waypoint Configuration

Rose's navigation system uses a **notecard-based configuration** that stores both the position and behavior for each waypoint.

### Waypoint Format

There are two formats depending on waypoint type:

#### Transient Waypoints (Pass-Through)
```
WAYPOINT0=<128.5, 128.5, 21.0>
```
Just a position vector - Rose walks through without stopping.

#### Linger/Sit Waypoints (Activities)
```
WAYPOINT1=<130.2, 125.8, 21.0>|{"type":"linger","name":"reception desk","orientation":0,"time":60,"animation":"stand_friendly","attachments":[]}
```
Position vector + pipe separator + JSON configuration for the activity.

## Setting Up Waypoints

### Option 1: Using Training Mode (Recommended)

1. **Start Training Mode**: Have an authorized user say "Rose, start training" or use the admin terminal
2. **Tap at Each Location**: Touch Rose at each waypoint location you want to configure
3. **Configure Each Waypoint**: Answer the prompts for:
   - Type (transient/linger/sit)
   - Name (activity description)
   - Duration (for linger/sit)
   - Orientation (direction to face)
   - Animation (optional)
   - Attachments (optional)
4. **Copy Output**: The Training script outputs each waypoint configuration to chat like:
   ```
   WAYPOINT0=<128.5, 128.5, 21.0>|{"type":"linger","name":"Standing at desk",...}
   ```
5. **Paste into Notecard**: Copy all the WAYPOINT lines from chat and paste them into `[WPP]WaypointConfig` notecard
6. **Reset Script**: After updating the notecard, reset the [WPP]WPManager script to reload

### Option 2: Manual Configuration

If you know the positions (from debug output or coordinates), you can manually create entries:

1. **Edit the notecard**: Open `[WPP]WaypointConfig` notecard in Second Life
2. **Add waypoint entries**: Use the format shown above
3. **Example entry**:
   ```
   WAYPOINT0=<100.5, 100.5, 21.0>|{"type":"linger","name":"checking mail","time":30,"attachments":[]}
   ```
4. **Save and reset**: Save the notecard and reset [WPP]WPManager script

## Common Issues

### Issue: "0 waypoints" reported

**Cause**: Notecard only has example entries without position vectors, or entries are commented out

**Solution**: 
- Uncomment the example waypoints (remove `#` at start of line), OR
- Run Training Mode to generate real waypoint configurations

### Issue: Waypoints not parsing correctly

**Cause**: Missing position vector or pipe separator

**Fix**: Ensure format is:
- Transient: `WAYPOINT0=<x, y, z>`
- Linger/Sit: `WAYPOINT0=<x, y, z>|{...json...}`

### Issue: Training Mode output not appearing

**Cause**: Not authorized as trainer

**Solution**: Add your UUID to the authorization list (check RoseConfig for trainer setup)

## Verifying Configuration

After setting up waypoints, you should see in chat:
```
Loading wp config: [WPP]WaypointConfig
19 waypoints
```

If you see "0 waypoints", check:
1. Are waypoints commented out (lines start with `#`)?
2. Do waypoints include position vectors?
3. Is the format correct (vector followed by `|` for linger/sit)?

## Migration from Old System

If you had waypoints configured in the old monolithic script:

1. The configuration format is the **same** - no changes needed
2. Simply copy your existing waypoint entries from the old notecard
3. Paste them into `[WPP]WaypointConfig`
4. The new script will parse them identically

## Example Working Configuration

```
# Working configuration with 3 waypoints
WAYPOINT0=<128.5, 128.5, 21.0>
WAYPOINT1=<130.2, 125.8, 21.0>|{"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
WAYPOINT2=<132.1, 130.4, 21.0>|{"type":"linger","name":"watering plants","orientation":90,"time":45,"animation":"watering","attachments":[]}
```

This would result in:
```
Loading wp config: [WPP]WaypointConfig
3 waypoints
```
