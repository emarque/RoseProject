# API Key Configuration Fix

## Problem

HTTP 401 errors were occurring due to invalid API key:

```
[11:31:48 AM] Rose_v5: HTTP 401
[11:34:51 AM] Rose_v5: HTTP 401
```

Server logs showed:
```
[19:34:51 WRN] Invalid API key attempted from ::1
[19:34:51 INF] HTTP POST /api/activities/batch responded 401 in 6.1130 ms
```

The issue was that the `API_KEY` variable in `[WPP]WPReporter.lsl` was set to the placeholder value `"your-api-key-here"` instead of an actual API key.

## Root Cause

The Reporter script ships with a placeholder API key:
```lsl
string API_KEY = "your-api-key-here";
```

This is intentional for security (don't hardcode real keys in public repos), but it meant:
1. Users needed to manually update the key
2. No clear indication that this needed to be done
3. Generic "HTTP 401" error gave no hint about the API key issue

## Solution

Enhanced `[WPP]WPReporter.lsl` with:
1. Clear documentation about API key requirement
2. Startup warning if API key not configured
3. Specific error messages for 401 responses

### Enhanced Documentation (Lines 1-10)

```lsl
// [WPP]WPReporter.lsl
// Activity Reporter - Tracks and reports activities via API

// CONFIGURATION
// ⚠️ IMPORTANT: Update API_KEY with your actual API key from the Rose Receptionist API
// Get your API key from your Rose Receptionist dashboard
// Without a valid API key, all API calls will fail with HTTP 401 errors
string API_ENDPOINT = "https://rosercp.pantherplays.com/api";
string API_KEY = "your-api-key-here";  // ⚠️ CHANGE THIS TO YOUR ACTUAL API KEY
```

Clear warnings with emoji make it obvious this needs attention.

### Startup Warning (Lines 146-154)

```lsl
state_entry()
{
    llOwnerSay("Reporter ready");
    last_batch_time = llGetUnixTime();
    
    // Warn if API_KEY is not configured
    if (API_KEY == "your-api-key-here")
    {
        llOwnerSay("⚠️ WARNING: API_KEY not configured!");
        llOwnerSay("Update API_KEY in [WPP]WPReporter script");
        llOwnerSay("All API calls will fail with HTTP 401");
    }
}
```

When the script starts, if API_KEY is still the default placeholder, user sees:
```
Reporter ready
⚠️ WARNING: API_KEY not configured!
Update API_KEY in [WPP]WPReporter script
All API calls will fail with HTTP 401
```

### Specific 401 Error Messages (Lines 218-222)

```lsl
else if (status == 401)
{
    llOwnerSay("⚠️ HTTP 401: Invalid API key");
    llOwnerSay("Please update API_KEY in [WPP]WPReporter script");
    llOwnerSay("Get your API key from Rose Receptionist dashboard");
}
```

When a 401 error occurs, user now sees:
```
⚠️ HTTP 401: Invalid API key
Please update API_KEY in [WPP]WPReporter script
Get your API key from Rose Receptionist dashboard
```

Instead of just:
```
HTTP 401
```

## How to Fix

### Step 1: Get Your API Key

1. Log in to your Rose Receptionist dashboard
2. Navigate to Settings or API section
3. Generate or copy your API key

### Step 2: Update the Script

1. Open `[WPP]WPReporter.lsl` in Second Life
2. Find line 6: `string API_KEY = "your-api-key-here";`
3. Replace `"your-api-key-here"` with your actual API key in quotes
4. Save the script

Example:
```lsl
// BEFORE:
string API_KEY = "your-api-key-here";

// AFTER (with your real key):
string API_KEY = "sk_live_a1b2c3d4e5f6g7h8i9j0";
```

### Step 3: Verify

After updating and saving:
1. Script will reset automatically
2. You should see `Reporter ready` without any warnings
3. HTTP 401 errors should stop
4. Activity reporting will work

## Security Notes

### DO NOT commit your API key to version control

The placeholder value exists specifically so real API keys don't get accidentally committed to Git.

If you're developing:
1. Keep the placeholder in the repository
2. Update it locally in Second Life
3. Never save the real key back to the repository
4. Use `.gitignore` or similar to exclude keys

### API Key Best Practices

1. **Keep it secret**: Don't share your API key publicly
2. **Rotate regularly**: Generate new keys periodically
3. **Use separate keys**: Different keys for dev/test/prod
4. **Monitor usage**: Check API logs for unauthorized access
5. **Revoke if compromised**: Immediately generate new key if leaked

## Troubleshooting

### Still getting 401 after updating key

1. **Check for typos**: Make sure you copied the entire key correctly
2. **Check quotes**: Key must be in quotes: `"sk_live_..."`
3. **Check expiration**: Some API keys expire, generate a new one
4. **Check permissions**: Key might not have required permissions
5. **Check endpoint**: Verify API_ENDPOINT matches your server

### Warning still shows after updating

1. Make sure you **saved** the script after editing
2. Script should have reset automatically after save
3. If not, manually reset the script
4. Check that you didn't just add your key in a comment

### 401 on some requests but not others

1. Some API endpoints might require different permissions
2. Check server logs to see which endpoint is failing
3. Verify your API key has all required scopes

## Error Messages Reference

### Startup Messages

**Good (configured):**
```
Reporter ready
```

**Bad (not configured):**
```
Reporter ready
⚠️ WARNING: API_KEY not configured!
Update API_KEY in [WPP]WPReporter script
All API calls will fail with HTTP 401
```

### Runtime Messages

**Generic error (old):**
```
HTTP 401
```

**Specific error (new):**
```
⚠️ HTTP 401: Invalid API key
Please update API_KEY in [WPP]WPReporter script
Get your API key from Rose Receptionist dashboard
```

### Other HTTP Status Codes

- **200**: Success (no message)
- **401**: Invalid API key (detailed message shown above)
- **429**: Rate limiting (`"429 throttled"`)
- **Other**: Generic `"HTTP XXX"` message

## Testing

To verify your API key is working:

1. Update the key in the script
2. Save and let script reset
3. Wait for Rose to complete an activity
4. Should see activity batching messages (if enabled)
5. Check server logs - should show 200 responses, not 401
6. Verify activities appear in dashboard

## Implementation Details

### API Key Usage

The API key is sent in HTTP requests as a custom header:
```lsl
HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY
```

### Server-Side Validation

The server (Rose Receptionist API) validates the key:
1. Extracts `X-API-Key` header from request
2. Checks if key exists in database
3. Checks if key is active/not expired
4. Checks if key has required permissions
5. Returns 401 if any check fails

### Security Through Headers

Using a custom header (`X-API-Key`) instead of URL parameters is more secure:
- Not logged in most web server access logs
- Not visible in browser history
- Not cached by proxies
- Easier to filter out of error logs

## Related Files

- `[WPP]WPReporter.lsl` - Main script with API key configuration
- `RoseConfig.txt` - General configuration (no API keys)
- Server API documentation - Details on key generation and permissions

## See Also

- API documentation for key management
- Security best practices for LSL scripts
- HTTP error code reference
