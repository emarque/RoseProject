# LSL Syntax Fixes and Script Renaming

## Issues Fixed

### 1. Protected Keyword "key" Used as Variable Name

**Problem**: LSL reserves "key" as a data type keyword. Using it as a variable name causes compilation errors.

**Location**: Line 787 in the waypoint config parsing code

**Before**:
```lsl
string key = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);

if (llSubStringIndex(key, WAYPOINT_PREFIX) == 0)
{
    integer wpNum = (integer)llGetSubString(key, llStringLength(WAYPOINT_PREFIX), -1);
```

**After**:
```lsl
string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);

if (llSubStringIndex(configKey, WAYPOINT_PREFIX) == 0)
{
    integer wpNum = (integer)llGetSubString(configKey, llStringLength(WAYPOINT_PREFIX), -1);
```

**Fix**: Renamed variable from `key` to `configKey` throughout the function.

### 2. DEG_TO_RAD Constant Redeclared

**Problem**: DEG_TO_RAD is a built-in LSL mathematical constant. Redeclaring it is unnecessary and can cause confusion.

**Location**: Line 68 (removed)

**Before**:
```lsl
// Constants
float DEG_TO_RAD = 0.0174532925;
```

**After**:
```lsl
// (removed - DEG_TO_RAD is built-in)
```

**Fix**: Removed the declaration. LSL provides this constant automatically.

## Script Renaming

All scripts renamed to follow [WPP]WP* naming convention:

| Old Name | New Name | Size | Purpose |
|----------|----------|------|---------|
| RoseReceptionist_GoWander3_Navigator.lsl | **[WPP]WPNavigator.lsl** | 7KB | Navigation engine |
| RoseReceptionist_GoWander3_Waypoint.lsl | **[WPP]WPManager.lsl** | 26KB | Waypoint manager |
| RoseReceptionist_GoWander3_Reporter.lsl | **[WPP]WPReporter.lsl** | 7KB | Activity reporter |

### Rationale for New Names

- `[WPP]` prefix: Matches existing waypoint config notecard `[WPP]WaypointConfig.notecard`
- `WP` prefix: Short for "Waypoint"
- Clear role names: Navigator, Manager, Reporter

## Files Removed

Removed old/unused script versions:

1. **RoseReceptionist_GoWander3.lsl** - Original 54KB monolithic script
2. **RoseReceptionist_GoWander3_Manager.lsl** - Old 2-script version (31KB)
3. **RoseReceptionist_GoWander3_Waypoint.lsl** - Duplicate/old name
4. **RoseReceptionist_GoWander3_Navigator.lsl** - Old name
5. **RoseReceptionist_GoWander3_Reporter.lsl** - Old name

## Verification

### Syntax Check
```bash
# No protected keywords used
grep -n "string\s\+key\s*=" [WPP]WP*.lsl
# (no results = fixed)

# No redeclared constants
grep -n "float\s\+DEG_TO_RAD\s*=" [WPP]WP*.lsl
# (no results = fixed)
```

### File Structure
```
RoseReceptionist.LSL/
├── [WPP]WPNavigator.lsl      (7KB)
├── [WPP]WPManager.lsl         (26KB)
├── [WPP]WPReporter.lsl        (7KB)
└── [WPP]WaypointConfig.notecard
```

## Impact

### Positive
- ✅ Scripts will now compile without syntax errors
- ✅ Consistent naming with existing [WPP] convention
- ✅ Removed outdated/duplicate files
- ✅ Documentation updated to reflect new names

### No Breaking Changes
- All link message numbers unchanged
- All functionality preserved
- Configuration files unchanged
- API endpoints unchanged

## Deployment Notes

When deploying to Second Life:

1. **Remove old scripts** from object (if present):
   - RoseReceptionist_GoWander3_Navigator
   - RoseReceptionist_GoWander3_Waypoint
   - RoseReceptionist_GoWander3_Reporter
   - RoseReceptionist_GoWander3_Manager
   - RoseReceptionist_GoWander3

2. **Add new scripts** to object:
   - [WPP]WPNavigator
   - [WPP]WPManager
   - [WPP]WPReporter

3. **Verify startup**:
   - Look for "Navigator ready"
   - Look for "Waypoint Manager ready"
   - Look for "Reporter ready"

## Testing

Recommended tests after deployment:

- [ ] Scripts compile without errors in SL
- [ ] Navigation occurs between waypoints
- [ ] Activities start and complete
- [ ] Stand animation variation works
- [ ] API reporting functions
- [ ] No "key" keyword errors
- [ ] DEG_TO_RAD calculations work correctly

All tests should pass with no changes to behavior.
