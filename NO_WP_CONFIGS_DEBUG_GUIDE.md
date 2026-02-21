# "No wp configs" Debugging Guide

## Problem Description

Users report seeing "no wp configs" message **immediately after** seeing a successful waypoint load message like "19 waypoints".

## Diagnostic Output

The script now includes detailed diagnostic output:

```
Loading wp config: [WPP]WaypointConfig
19 waypoints (list len=152)
No wp configs (list len=0)
```

OR

```
Loading wp config: [WPP]WaypointConfig
0 waypoints (list len=0)
```

## Interpretation

### Scenario 1: Count > 0, then Count = 0
```
19 waypoints (list len=152)
No wp configs (list len=0)
```

**Meaning**: List was populated but then cleared/corrupted
**Likely Cause**: Stack heap collision during config load
**Solution**: Script is too close to memory limits

### Scenario 2: Count = 0 from start
```
0 waypoints (list len=0)
```

**Meaning**: Waypoints never loaded into the list
**Likely Causes**:
1. Config format doesn't match parser expectations
2. No matching WAYPOINT# entries found
3. All waypoints failed to parse

### Scenario 3: List has data but count = 0
```
19 waypoints (list len=152)
No wp configs (list len=152)
```

**Meaning**: List has data but `getWaypointCount()` can't parse it
**Likely Cause**: Logic bug in `getWaypointEntrySize()` or `getWaypointCount()`

## Configuration Format Check

Verify your `[WPP]WaypointConfig` notecard has correct format:

### JSON-Only Format (Most Common)
```
WAYPOINT0={"type":"transient","name":"hallway"}
WAYPOINT1={"type":"linger","name":"desk","orientation":0,"time":60}
WAYPOINT2={"type":"sit","name":"chair","orientation":180,"time":120,"animation":"sit"}
```

### Position + JSON Format
```
WAYPOINT0=<128.5, 128.5, 21.0>|{"type":"linger","name":"desk","orientation":0,"time":60}
```

### Position-Only Format
```
WAYPOINT0=<128.5, 128.5, 21.0>
```

## Common Issues

### Issue 1: Comments Breaking Parser
**Problem**: Comments on same line as config
```
WAYPOINT0={"type":"transient"} # This breaks parsing!
```

**Fix**: Remove inline comments or put on separate line
```
# Hallway corner waypoint
WAYPOINT0={"type":"transient","name":"hallway"}
```

### Issue 2: Missing Waypoint Numbers
**Problem**: Non-sequential waypoint numbers
```
WAYPOINT0=...
WAYPOINT2=...  # Missing WAYPOINT1!
WAYPOINT5=...  # Missing WAYPOINT3 and WAYPOINT4!
```

**Fix**: Use sequential numbers starting from 0
```
WAYPOINT0=...
WAYPOINT1=...
WAYPOINT2=...
```

### Issue 3: Malformed JSON
**Problem**: JSON syntax errors
```
WAYPOINT0={"type":"linger","name":"desk}  # Missing closing quote and brace
WAYPOINT1={'type':'sit'}  # Using single quotes instead of double
```

**Fix**: Use proper JSON syntax
```
WAYPOINT0={"type":"linger","name":"desk"}
WAYPOINT1={"type":"sit","name":"chair"}
```

### Issue 4: Stack Heap Collision
**Problem**: Too many waypoints or too much data causing memory issues

**Symptoms**:
- List shows data initially, then becomes empty
- Script reports "Stack Heap Collision" error
- Random behavior or crashes

**Fixes**:
1. Reduce number of waypoints
2. Simplify waypoint configurations (shorter names, fewer attachments)
3. Remove unnecessary animations or attachment data
4. Split into multiple notecard files (not yet supported)

## List Length Calculation

For JSON-only format:
- **Transient waypoint**: 2 elements `[wpNum, ZERO_VECTOR]`
- **Linger/Sit waypoint**: 8 elements `[wpNum, ZERO_VECTOR, type, name, orientation, time, anim, attachJson]`

Example with 19 waypoints (10 transient, 9 linger/sit):
- Expected list length: (10 × 2) + (9 × 8) = 20 + 72 = 92 elements

If you see list length of 152 for 19 waypoints:
- 152 / 8 = 19, so all 19 waypoints are linger/sit type ✅

## Troubleshooting Steps

1. **Check diagnostic output** - Look at the list length numbers
2. **Verify notecard format** - Ensure no syntax errors
3. **Test with minimal config** - Try 1-2 waypoints first
4. **Check for stack heap collision** - Look for error messages
5. **Verify sequential numbering** - Start from WAYPOINT0, no gaps

## Test Configuration

Use this minimal test config to verify parsing works:

```
# Test configuration with 2 waypoints
WAYPOINT0={"type":"transient","name":"test1"}
WAYPOINT1={"type":"linger","name":"test2","orientation":0,"time":10}
```

Expected output:
```
Loading wp config: [WPP]WaypointConfig
2 waypoints (list len=10)
```

If this works, gradually add more waypoints to find the breaking point.

## Reporting Issues

When reporting issues, include:
1. The complete diagnostic output
2. First 5 waypoint entries from your notecard
3. Total number of waypoints in your config
4. Whether it worked with the monolithic script before
