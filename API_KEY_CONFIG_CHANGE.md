# API Key Configuration Change

## Overview

The WPReporter script now reads the API_KEY from the RoseConfig.txt notecard instead of requiring it to be hardcoded in the script file.

## What Changed

### Before (Old Method)
- API_KEY was hardcoded in [WPP]WPReporter.lsl script
- Users had to edit the script file to set their API key
- Required script editing knowledge
- Less convenient for configuration management

```lsl
// Old way - in [WPP]WPReporter.lsl
string API_KEY = "your-actual-api-key";  // ⚠️ CHANGE THIS
```

### After (New Method)
- API_KEY is read from RoseConfig.txt notecard
- Users edit the notecard (much easier)
- No script editing required
- Consistent with other configuration settings

```
# New way - in RoseConfig.txt
API_KEY=your-actual-api-key
```

## Benefits

✅ **Easier to Configure**: Edit notecard instead of script code
✅ **Consistent Pattern**: All settings now in one config file
✅ **No Script Knowledge**: Users don't need to understand LSL
✅ **Better Organization**: API key grouped with other config
✅ **More Secure**: Notecard permissions can be set separately
✅ **Easier Distribution**: Single config file to share/backup

## How to Use

### Setting Your API Key

1. **Open RoseConfig.txt notecard**
   - Right-click the Rose object
   - Choose "Edit"
   - Go to "Contents" tab
   - Double-click "RoseConfig" notecard

2. **Find the API_KEY line** (near the top):
   ```
   API_KEY=your-api-key-here
   ```

3. **Replace with your actual API key**:
   ```
   API_KEY=abc123def456ghi789
   ```

4. **Save the notecard**
   - Click "Save" button
   - Close the notecard editor

5. **Reset the Reporter script**:
   - In object Contents, right-click [WPP]WPReporter
   - Choose "Reset Script"
   - Or reset the entire object

### Getting Your API Key

1. Visit your Rose Receptionist dashboard
2. Navigate to API settings
3. Generate or copy your API key
4. Paste into RoseConfig.txt as shown above

## Technical Details

### Implementation

The Reporter script now:

1. **Reads RoseConfig on startup**:
   ```lsl
   state_entry() {
       if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD) {
           notecardQuery = llGetNotecardLine("RoseConfig", 0);
       }
   }
   ```

2. **Parses API_KEY from notecard**:
   ```lsl
   dataserver(key query_id, string data) {
       if (configKey == "API_KEY") {
           API_KEY = value;
       }
   }
   ```

3. **Warns if not configured**:
   ```lsl
   if (API_KEY == "your-api-key-here") {
       llOwnerSay("⚠️ WARNING: API_KEY not configured!");
       llOwnerSay("Add API_KEY to RoseConfig notecard");
   }
   ```

### Config File Format

RoseConfig.txt now includes:

```
# =============================================================================
# API Configuration
# Get your API key from your Rose Receptionist dashboard
# Without a valid API key, all API calls will fail with HTTP 401 errors
# =============================================================================
API_KEY=your-api-key-here

# Other settings...
SHIFT_START_TIME=09:00
SHIFT_END_TIME=17:00
...
```

### Other Settings Read

The Reporter also reads these from RoseConfig:
- `SHIFT_START_TIME` - When work shift starts
- `SHIFT_END_TIME` - When work shift ends  
- `DAILY_REPORT_TIME` - When to generate daily report

## Troubleshooting

### "No RoseConfig found" Message

**Problem**: Reporter can't find RoseConfig notecard

**Solutions**:
1. Check that RoseConfig notecard is in object Contents
2. Verify notecard is named exactly "RoseConfig" (no .txt extension in-world)
3. Make sure notecard has correct permissions

### "API_KEY not configured" Warning

**Problem**: API_KEY still has default value

**Solutions**:
1. Open RoseConfig notecard
2. Update the API_KEY line
3. Save the notecard
4. Reset the Reporter script

### HTTP 401 Errors

**Problem**: API calls failing with 401 Unauthorized

**Solutions**:
1. Verify API key is correct (no typos)
2. Check API key is still valid (not expired/revoked)
3. Ensure no extra spaces before/after API key
4. Generate new API key if needed

## Migration Steps

### For Existing Users

If you previously set API_KEY in the script:

1. **Find your old API key**:
   - Open [WPP]WPReporter.lsl
   - Look for `string API_KEY = "...";`
   - Copy your actual API key

2. **Add to RoseConfig**:
   - Open RoseConfig notecard
   - Find `API_KEY=your-api-key-here`
   - Replace with your key

3. **Update script** (optional):
   - Get latest version of [WPP]WPReporter.lsl
   - Or keep your old version (still works)

4. **Reset scripts**:
   - Reset Reporter to load from config
   - Verify no warnings appear

### For New Users

1. Get your API key from dashboard
2. Add it to RoseConfig notecard
3. That's it! No script editing needed

## Security Notes

### Notecard Security

- Notecards can have restricted permissions
- Set to "owner only" for privacy
- API key not visible to others unless they can read notecard
- Consider using object permissions for added security

### Best Practices

✅ **DO**:
- Keep RoseConfig notecard permissions restricted
- Use unique API keys per installation
- Rotate API keys periodically
- Back up your RoseConfig with API key removed

❌ **DON'T**:
- Share your API key publicly
- Use same API key across multiple installations
- Copy RoseConfig with API key to public places
- Leave API key in default state

## Related Documentation

- [API Key Configuration Fix](API_KEY_CONFIGURATION_FIX.md) - Original issue and solution
- [RoseConfig.txt](RoseReceptionist.LSL/RoseConfig.txt) - Full config file
- [WPReporter Script](RoseReceptionist.LSL/[WPP]WPReporter.lsl) - Reporter implementation

## Summary

This change makes API key configuration:
- **Easier**: Edit notecard vs editing script
- **Consistent**: All config in one place
- **Safer**: Better permission control
- **Standard**: Matches other settings

No functionality is lost - only the configuration method improved!
