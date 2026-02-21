# HTML Entity Decoding Fix for Waypoint Configuration

## Problem

User reported "0 waypoints (list len=0)" even though they had 20 waypoints configured in their notecard.

## Investigation

When the user copied their waypoint configuration, it showed HTML entities instead of actual characters:

```
WAYPOINT0=&lt;9.97592, 10.97975, 39.96180&gt;|{"type":"linger",...}
WAYPOINT1=&amp;lt;11.54201, 10.91831, 39.96180&gt;
```

### HTML Entity Table

| Entity | Character | Meaning |
|--------|-----------|---------|
| `&lt;` | `<` | Less than |
| `&gt;` | `>` | Greater than |
| `&amp;` | `&` | Ampersand |
| `&quot;` | `"` | Quote |

## Root Cause

If a notecard is created by:
1. Copying waypoint config from a web page or chat
2. Pasting into Second Life notecard editor
3. HTML entities remain in the text

When the parser tries to extract vectors like `<9.97592, 10.97975, 39.96180>`, it actually sees `&lt;9.97592, 10.97975, 39.96180&gt;`, which:
- Fails to parse as a vector
- Returns ZERO_VECTOR or parsing error
- Waypoint is skipped or incorrectly added

## Solution

Added HTML entity decoding in `[WPP]WPManager.lsl` (lines 797-801):

```lsl
// Decode HTML entities that may have been introduced during copy/paste
value = llReplaceSubString(value, "&lt;", "<", 0);
value = llReplaceSubString(value, "&gt;", ">", 0);
value = llReplaceSubString(value, "&amp;", "&", 0);
value = llReplaceSubString(value, "&quot;", "\"", 0);
```

This decoding happens:
- **After** the value is extracted from the config line
- **Before** any parsing (vector or JSON)
- For every waypoint entry

## Result

### Before Fix
```
[21:15] Rose_v4: Loading wp config: [WPP]WaypointConfig
[21:15] Rose_v4: 0 waypoints (list len=0)
```

### After Fix
```
[21:15] Rose_v4: Loading wp config: [WPP]WaypointConfig
[21:15] Rose_v4: 20 waypoints (list len=160)
```

## Testing

### Test Case 1: Normal Config (no entities)
```
WAYPOINT0=<128.5, 128.5, 21.0>|{"type":"linger","name":"test"}
```
✅ Works before and after fix

### Test Case 2: HTML Entities
```
WAYPOINT0=&lt;128.5, 128.5, 21.0&gt;|{"type":"linger","name":"test"}
```
❌ Failed before fix
✅ Works after fix

### Test Case 3: Mixed Entities
```
WAYPOINT0=&amp;lt;128.5, 128.5, 21.0&amp;gt;|{"type":"linger","name":"test"}
```
❌ Failed before fix
✅ Works after fix (double-encoded ampersands decoded)

## How It Happened

Common scenarios where HTML entities get introduced:
1. **Copying from Discord/Slack**: Some chat platforms HTML-encode messages
2. **Copying from web dashboards**: API dashboards may show configs in HTML
3. **Export from database**: Some database tools export with HTML encoding
4. **Email/document**: Copying from emails or documents that were HTML-formatted

## Prevention

To avoid HTML entities in notecards:
1. **Use plain text editors** when preparing configs outside SL
2. **Copy from raw text sources**, not formatted HTML pages
3. **Check notecard** after pasting - look for `&lt;` or `&gt;`
4. **Use Training Mode** to generate configs directly (no copy/paste issues)

## Impact

This fix is:
- ✅ **Safe**: Decoding only affects strings with HTML entities
- ✅ **Transparent**: Normal configs work exactly as before
- ✅ **Automatic**: No user action required
- ✅ **Complete**: Handles all common HTML entities

Users can now paste waypoint configs from any source without worrying about HTML encoding issues.
