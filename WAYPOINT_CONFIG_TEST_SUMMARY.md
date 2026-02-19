# Test Summary: Stack Heap Collision Fix

## Test Case: Example Waypoint Configuration

### Input
```
WAYPOINT0=<9.97592, 10.97975, 39.96180>|{"type":"linger","name":"Standing at my desk","orientation":90,"time":15,"attachments":[]}
```

### Expected Parsing Results

#### Position Vector
- X: 9.97592
- Y: 10.97975
- Z: 39.96180

#### JSON Parsing (via parseWaypointJSON)
The JSON portion: `{"type":"linger","name":"Standing at my desk","orientation":90,"time":15,"attachments":[]}`

Should parse to a list containing:
1. **type**: "linger"
2. **name**: "Standing at my desk"
3. **orientation**: 90
4. **time**: 15
5. **animation**: "" (empty, not present in JSON)
6. **attachments**: "[]"

### Internal Storage Format

For a non-transient waypoint (linger/sit), the waypoint_configs list stores:
```
[wpNum, pos, type, name, orientation, time, animation, attachments]
```

For WAYPOINT0, this would be:
```
[0, <9.97592, 10.97975, 39.96180>, "linger", "Standing at my desk", 90, 15, "", "[]"]
```

### Stack Optimization Benefits

**Before optimization:**
- parseWaypointJSON used unbounded string searches (`-1` parameter)
- Created multiple temporary strings for each field extraction
- Built list incrementally with `result += [value]` creating temp copies
- Risk of stack-heap collision with complex waypoint configs

**After optimization:**
- All string searches use bounded ranges (20-500 chars depending on field)
- Cached substrings to avoid redundant operations
- Single list construction at return statement
- Eliminated 70 lines of code including confirmation dialog system
- Removed verbose reload messages during critical loading phase

### Expected Behavior

1. **Script Load**: Script should load without "Stack-Heap Collision" error
2. **Waypoint Loading**: Should successfully parse and load waypoint configs
3. **Wander Toggle**: Direct execution without confirmation prompt
4. **Config Reload**: Silent reload when notecard changes (no "reloading..." message)
5. **Memory Usage**: Reduced stack usage during JSON parsing operations

### Test Verification Steps

1. Compile the script - should compile without errors
2. Add the script to an object in Second Life
3. Create [WPP]WaypointConfig notecard with the example waypoint
4. Script should load and parse the config without stack-heap collision
5. Check debug output: "Loaded 1 waypoints"
6. Wander system should function normally with the parsed waypoint data

### Known Limitations

The bounded string searches have these limits:
- Type field: 20 characters (sufficient for "transient", "linger", "sit")
- Name field: 100 characters (sufficient for typical activity names)
- Animation field: 50 characters (sufficient for animation names)
- Attachments JSON: 500 characters (sufficient for typical attachment arrays)

These bounds are conservative and well above typical values, preventing stack issues while accommodating reasonable use cases.
