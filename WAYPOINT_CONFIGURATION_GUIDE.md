# Waypoint Configuration Setup Guide

## Problem: "0 waypoints configured"

If the script reports "0 waypoints configured" even though you have waypoints set up, check that your `[WPP]WaypointConfig` notecard has properly formatted waypoint entries.

## Understanding Waypoint Configuration

Rose's navigation system uses **waypoint prims** (physical objects named "Wander0", "Wander1", etc.) combined with **notecard configuration** that defines activities at each waypoint.

### Waypoint Format

The notecard supports three formats:

#### Format 1: JSON Only (Recommended)
```
WAYPOINT0={"type":"transient","name":"hallway"}
WAYPOINT1={"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
```
**Positions are read from waypoint prims in the world** (Wander0, Wander1, etc.)
This is the most common format.

#### Format 2: Position Only
```
WAYPOINT0=<128.5, 128.5, 21.0>
```
Just a position vector - Rose walks through without stopping (transient waypoint).

#### Format 3: Position + JSON (Explicit Override)
```
WAYPOINT1=<130.2, 125.8, 21.0>|{"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
```
Explicit position + pipe separator + JSON configuration.
Used when you want to override the waypoint prim's location.

## Setting Up Waypoints

### Step 1: Create Waypoint Prims (In Second Life)

1. **Create prims** in Second Life and name them sequentially: `Wander0`, `Wander1`, `Wander2`, etc.
2. **Place them** at the locations where you want Rose to go
3. Rose will automatically detect these prims and navigate to them in numerical order

### Step 2: Configure Activities (In Notecard)

Edit the `[WPP]WaypointConfig` notecard with your waypoint configurations:

#### For JSON-Only Format (Uses Prim Positions)
```
WAYPOINT0={"type":"transient","name":"hallway corner"}
WAYPOINT1={"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
WAYPOINT2={"type":"linger","name":"watering plants","orientation":90,"time":45,"animation":"watering","attachments":[{"item":"Watering Can","point":"RightHand"}]}
```

The script will find the "Wander0", "Wander1", "Wander2" prims in the world and use their positions.

#### Using Training Mode (Optional)

1. **Start Training Mode**: Have an authorized user say "Rose, start training" or use the admin terminal
2. **Tap at Each Location**: Touch Rose at each waypoint location
3. **Configure Each Waypoint**: Answer the prompts for type, name, duration, orientation, animation, attachments
4. **Copy Output**: The Training script outputs each waypoint configuration to chat
5. **Paste into Notecard**: Copy the WAYPOINT lines from chat and paste them into `[WPP]WaypointConfig` notecard

Training Mode can output in either format (JSON-only or Position+JSON) depending on your needs.

## Common Issues

### Issue: "0 waypoints" reported

**Cause 1**: All waypoint entries are commented out (lines start with `#`)

**Solution**: Remove the `#` from the beginning of your WAYPOINT lines

**Cause 2**: Waypoint entries have incorrect format

**Solution**: Ensure format is one of:
- JSON only: `WAYPOINT0={"type":"transient","name":"activity"}`
- Position only: `WAYPOINT0=<x, y, z>`
- Position + JSON: `WAYPOINT0=<x, y, z>|{...json...}`

**Cause 3**: Notecard is empty or only has comments

**Solution**: Add your waypoint configurations to the notecard

### Issue: Waypoints not working correctly

**Cause**: Missing waypoint prims in the world (for JSON-only format)

**Solution**: 
- Create prims named "Wander0", "Wander1", etc. at the desired locations
- OR use Position+JSON format to specify locations explicitly

### Issue: Training Mode output not appearing

**Cause**: Not authorized as trainer

**Solution**: Add your UUID to the authorization list (check RoseConfig for trainer setup)

## Verifying Configuration

After setting up waypoints, you should see in chat:
```
Loading wp config: [WPP]WaypointConfig
4 waypoints
```

The number should match your configured waypoints.

If you see "0 waypoints", check:
1. Are waypoints commented out (lines start with `#`)?
2. Is the format correct (JSON, vector, or vector|JSON)?
3. Are there any actual WAYPOINT entries in the notecard?

## Example Working Configuration

### Example 1: JSON-Only (Most Common)
```
WAYPOINT0={"type":"transient","name":"hallway corner"}
WAYPOINT1={"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
WAYPOINT2={"type":"linger","name":"watering plants","orientation":90,"time":45,"animation":"watering","attachments":[]}
```

Requires "Wander0", "Wander1", "Wander2" prims in the world.

Result:
```
Loading wp config: [WPP]WaypointConfig
3 waypoints
```

### Example 2: Mixed Format
```
WAYPOINT0=<128.5, 128.5, 21.0>
WAYPOINT1=<130.2, 125.8, 21.0>|{"type":"linger","name":"reception desk","orientation":0,"time":60,"attachments":[]}
WAYPOINT2={"type":"sit","name":"taking a break","time":60,"attachments":[]}
```

WAYPOINT0: Uses explicit position, no activity (transient)
WAYPOINT1: Uses explicit position + activity configuration
WAYPOINT2: Uses Wander2 prim position + sit activity

Result:
```
Loading wp config: [WPP]WaypointConfig
3 waypoints
```
