# SUBSCRIBER_KEY Rename

## Overview

The WPReporter script previously used `API_KEY` as the variable name and configuration parameter, while other scripts (RoseReceptionist_Main.lsl and RoseAdminTerminal.lsl) used `SUBSCRIBER_KEY`. This inconsistency has been resolved by renaming `API_KEY` to `SUBSCRIBER_KEY` throughout the codebase.

### Why This Change

**Consistency**: All scripts now use the same terminology
**Clarity**: "Subscriber key" better describes its purpose
**Maintainability**: Easier to understand and maintain
**Alignment**: Matches existing documentation and API design

## Changes Made

### RoseConfig.txt

**Before**:
```
# =============================================================================
# API Configuration
# Get your API key from your Rose Receptionist dashboard
# Without a valid API key, all API calls will fail with HTTP 401 errors
# =============================================================================
API_KEY=your-api-key-here
```

**After**:
```
# =============================================================================
# API Configuration
# Get your subscriber key from your Rose Receptionist dashboard
# Without a valid subscriber key, all API calls will fail with HTTP 401 errors
# =============================================================================
SUBSCRIBER_KEY=your-subscriber-key-here
```

**Changes**:
- Configuration parameter renamed from `API_KEY` to `SUBSCRIBER_KEY`
- Comments updated to reference "subscriber key"
- Default value updated to "your-subscriber-key-here"

### [WPP]WPReporter.lsl

#### Variable Declaration

**Before**:
```lsl
string API_KEY = "your-api-key-here";  // Will be loaded from RoseConfig.txt
```

**After**:
```lsl
string SUBSCRIBER_KEY = "your-subscriber-key-here";  // Will be loaded from RoseConfig.txt
```

#### HTTP Header Usage

**Before**:
```lsl
HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY,
```

**After**:
```lsl
HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY,
```

**Note**: The HTTP header name `X-API-Key` remains unchanged - only the variable name changes.

#### Config Parsing (dataserver event)

**Before**:
```lsl
if (configKey == "API_KEY")
{
    API_KEY = value;
}
```

**After**:
```lsl
if (configKey == "SUBSCRIBER_KEY")
{
    SUBSCRIBER_KEY = value;
}
```

#### Warning Messages

**Before**:
```lsl
llOwnerSay("⚠️ WARNING: API_KEY not configured!");
llOwnerSay("Add API_KEY to RoseConfig notecard");
```

**After**:
```lsl
llOwnerSay("⚠️ WARNING: SUBSCRIBER_KEY not configured!");
llOwnerSay("Add SUBSCRIBER_KEY to RoseConfig notecard");
```

#### HTTP Error Messages

**Before**:
```lsl
llOwnerSay("⚠️ HTTP 401: Invalid API key");
llOwnerSay("Please update API_KEY in RoseConfig notecard");
llOwnerSay("Get your API key from Rose Receptionist dashboard");
```

**After**:
```lsl
llOwnerSay("⚠️ HTTP 401: Invalid subscriber key");
llOwnerSay("Please update SUBSCRIBER_KEY in RoseConfig notecard");
llOwnerSay("Get your subscriber key from Rose Receptionist dashboard");
```

#### Default Value Checks

**Before**:
```lsl
if (API_KEY == "your-api-key-here")
```

**After**:
```lsl
if (SUBSCRIBER_KEY == "your-subscriber-key-here")
```

### Complete List of Changes

**Files Modified**:
1. `RoseConfig.txt` - Configuration parameter
2. `[WPP]WPReporter.lsl` - Variable, config parsing, messages

**Total Occurrences Changed**: 15

**Locations in WPReporter**:
- Line 8: Variable declaration
- Line 95: HTTP request (sendActivityBatch)
- Line 113: HTTP request (completeActivity)
- Line 124: HTTP request (getCurrentActivity)
- Line 140: HTTP request (generateDailyReport)
- Line 166: Default value check (state_entry)
- Line 168-170: Warning messages (state_entry)
- Line 240-242: HTTP error messages (http_response)
- Line 289: Config key check (dataserver)
- Line 291: Variable assignment (dataserver)
- Lines 318-322: Warning messages (dataserver EOF)

## Migration Guide

### For Existing Users

If you have an existing installation with `API_KEY` configured:

**Option 1: Update Config (Recommended)**
1. Open your RoseConfig notecard
2. Find the line: `API_KEY=your-actual-key-here`
3. Change to: `SUBSCRIBER_KEY=your-actual-key-here`
4. Save the notecard
5. Reset the Reporter script or wait for auto-reload

**Option 2: Keep Both (Temporary)**
You can temporarily have both lines:
```
API_KEY=your-actual-key-here
SUBSCRIBER_KEY=your-actual-key-here
```

The script will use `SUBSCRIBER_KEY` if present. This allows gradual migration.

### For New Users

Simply configure `SUBSCRIBER_KEY` in RoseConfig.txt:

```
SUBSCRIBER_KEY=your-actual-subscriber-key-here
```

Get your subscriber key from your Rose Receptionist dashboard.

### No Action Required

**These scripts already use SUBSCRIBER_KEY**:
- `RoseReceptionist_Main.lsl`
- `RoseAdminTerminal.lsl`

They continue to work unchanged.

## Technical Details

### Variable Scope

The `SUBSCRIBER_KEY` variable is:
- **Script-local**: Only exists in [WPP]WPReporter.lsl
- **Read from config**: Loaded during initialization
- **Used for HTTP**: Passed as X-API-Key header
- **Default value**: "your-subscriber-key-here"

### HTTP Header

The HTTP header sent to the API remains:
```
X-API-Key: <subscriber-key-value>
```

The header name `X-API-Key` does not change - only the variable storing the value.

### Config Parsing

The dataserver event parses the config file looking for:
```
SUBSCRIBER_KEY=<value>
```

The parsing logic:
1. Reads line from notecard
2. Splits on `=` character
3. Trims whitespace
4. Compares key name
5. Assigns to variable if match

### Default Value Handling

If SUBSCRIBER_KEY is not found in config or has the default value:
- Warning messages display at startup
- HTTP 401 errors show with helpful message
- Prompts user to configure the key

### Backward Compatibility

**Important**: Old `API_KEY` parameter in RoseConfig will NOT be recognized after this change. You must update to `SUBSCRIBER_KEY`.

## Testing and Verification

### Test 1: Config Reading

**Steps**:
1. Add `SUBSCRIBER_KEY=test-key-123` to RoseConfig
2. Reset Reporter script
3. Watch for "Config loaded" message

**Expected**: No warnings about unconfigured key

### Test 2: HTTP Requests

**Steps**:
1. Configure valid subscriber key
2. Perform activity that triggers API call
3. Check HTTP response

**Expected**: Success (200) or valid error (not 401)

### Test 3: Missing Configuration

**Steps**:
1. Remove SUBSCRIBER_KEY line from RoseConfig
2. Reset Reporter script

**Expected**: 
```
⚠️ WARNING: SUBSCRIBER_KEY not configured in RoseConfig!
Add SUBSCRIBER_KEY to RoseConfig notecard
All API calls will fail with HTTP 401
```

### Test 4: Invalid Key

**Steps**:
1. Set `SUBSCRIBER_KEY=invalid-key`
2. Trigger API call

**Expected**:
```
⚠️ HTTP 401: Invalid subscriber key
Please update SUBSCRIBER_KEY in RoseConfig notecard
Get your subscriber key from Rose Receptionist dashboard
```

### Test 5: Default Placeholder

**Steps**:
1. Keep default: `SUBSCRIBER_KEY=your-subscriber-key-here`
2. Reset script

**Expected**: Warning about not being configured

## Troubleshooting

### Issue: Still Getting 401 Errors

**Possible Causes**:
1. SUBSCRIBER_KEY not updated in config
2. Still using old "your-subscriber-key-here" placeholder
3. Invalid key value
4. Typo in configuration

**Solutions**:
1. Check RoseConfig.txt has SUBSCRIBER_KEY (not API_KEY)
2. Verify key value is your actual subscriber key
3. Check for extra spaces or quotes
4. Reset Reporter script after config change

### Issue: Warning About API_KEY Not Found

**Cause**: Old version of script still running

**Solution**: 
1. Replace [WPP]WPReporter.lsl with new version
2. Reset script

### Issue: Config Not Loading

**Possible Causes**:
1. RoseConfig notecard not in object
2. Notecard permissions issue
3. Script reset before config fully loaded

**Solutions**:
1. Check notecard exists and is named exactly "RoseConfig"
2. Check notecard can be read by script
3. Wait for "Config loaded" message before testing

## Related Documentation

- `DEBUG_MODE_IMPLEMENTATION.md` - DEBUG mode features
- `SESSION_DEBUG_AND_SUBSCRIBER.md` - Session summary
- `API_KEY_CONFIGURATION_FIX.md` - Original API key setup guide (now outdated)

## Summary

The rename from `API_KEY` to `SUBSCRIBER_KEY` provides consistency across all Rose Receptionist scripts. The change is straightforward - update your RoseConfig.txt to use the new parameter name, and the scripts will work identically to before.

**Key Points**:
- Variable renamed in WPReporter only
- Config parameter renamed in RoseConfig.txt
- HTTP header name unchanged
- Migration is simple (update config line)
- Existing users must update their config
- New users start with correct parameter
