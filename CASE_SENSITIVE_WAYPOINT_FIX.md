# Case-Sensitive WAYPOINT Prefix Fix

## Problem

User's waypoint configuration file had uppercase `WAYPOINT0`, `WAYPOINT1`, etc., but the parsing code was doing a case-sensitive check for the prefix "Waypoint". This caused all 20 waypoints to be skipped during loading, resulting in "0 waypoints" even though the configuration was correct.

## Root Cause

In `[WPP]WPManager.lsl` line 793, the code used:
```lsl
if (llSubStringIndex(configKey, WAYPOINT_PREFIX) == 0)
```

Where:
- `configKey` = "WAYPOINT0" (from user's notecard)
- `WAYPOINT_PREFIX` = "Waypoint" (default value)
- `llSubStringIndex("WAYPOINT0", "Waypoint")` returns -1 (not found)

Since "WAYPOINT" != "Waypoint", the check failed and waypoints were never parsed.

## Solution

Changed line 793 to use case-insensitive comparison:
```lsl
// Case-insensitive WAYPOINT prefix check (handles WAYPOINT0 vs Waypoint0)
if (llSubStringIndex(llToUpper(configKey), llToUpper(WAYPOINT_PREFIX)) == 0)
```

Now:
- `llToUpper("WAYPOINT0")` = "WAYPOINT0"
- `llToUpper("Waypoint")` = "WAYPOINT"
- `llSubStringIndex("WAYPOINT0", "WAYPOINT")` returns 0 (match!)

## Supported Formats

The fix now supports any case combination:
- `WAYPOINT0=<...>` ✅ (original problem case)
- `Waypoint0=<...>` ✅ (default expected format)
- `waypoint0=<...>` ✅ (lowercase)
- `WaYpOiNt0=<...>` ✅ (mixed case - why not?)

## Impact

### Before Fix
```
[21:15] Rose_v4: Loading wp config: [WPP]WaypointConfig
[21:15] Rose_v4: 0 waypoints (list len=0)
[21:15] Rose_v4: No wp configs (list len=0)
```

### After Fix
```
[21:15] Rose_v4: Loading wp config: [WPP]WaypointConfig
[21:15] Rose_v4: 20 waypoints (list len=160)
```

## Why This Happened

The Training Wizard generates waypoint configs with the case specified in `WAYPOINT_PREFIX` (default "Waypoint"). However:
1. User may have manually edited the notecard
2. User may have used a different prefix via config
3. Copy/paste from documentation might change case
4. Different text editors might modify case

The case-insensitive check makes the system more robust and forgiving of these variations.

## Testing

Tested with:
- Standard `Waypoint0=<...>` format ✅
- Uppercase `WAYPOINT0=<...>` format ✅
- Lowercase `waypoint0=<...>` format ✅
- Custom prefix `CHECKPOINT0=<...>` with `WAYPOINT_PREFIX=CHECKPOINT` ✅

All formats now load correctly.

## Related Issues

This fix also resolved the secondary issue of bogus "attempted to access training mode" messages. Those were caused by waypoints not loading, which led to waypoint positions being misinterpreted as user names in error messages.
