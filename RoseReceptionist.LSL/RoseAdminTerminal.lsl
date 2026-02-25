// RoseAdminTerminal.lsl
// Standalone Admin Terminal for Rose Receptionist system
// Can be placed anywhere and reads authorized owners from notecard

// ============================================
// CONFIGURATION
// ============================================

// Your backend API URL (no trailing slash)
string API_ENDPOINT = "https://rosercp.pantherplays.com/api";

// SUBSCRIBER_KEY can be set here or in RoseConfig notecard
string SUBSCRIBER_KEY = "";

list TERMINAL_OWNERS = [];

// Link message numbers (for compatibility if part of linkset)
integer LINK_SENSOR_DETECTED = 1000;
integer LINK_CHAT_MESSAGE = 1001;
integer LINK_SPEAK = 1002;
integer LINK_ANIMATION = 1003;
integer LINK_HTTP_REQUEST = 1004;

// HTTP request tracking
list http_requests = []; // [request_id, type, data]

// Notecard reading
key notecardQuery;
integer notecardLine = 0;
string notecardName = "TerminalOwners";

// Admin menu state
integer adminMenuChannel;
integer adminMenuListener;
integer adminTextboxChannel;
integer adminTextboxListener;

// Subscriber management state
integer subListChannel;
integer subListListener;
list cached_subscribers = [];
string currentMenuAction = "";

// ============================================
// USER-DEFINED FUNCTIONS
// ============================================

showAdminMenu(key user)
{
    // Remove old menu listener if exists
    if (adminMenuListener != 0)
    {
        llListenRemove(adminMenuListener);
    }
    
    adminMenuChannel = -1000 - (integer)llFrand(9999);
    adminMenuListener = llListen(adminMenuChannel, "", user, "");
    
    llDialog(user,
        "🔧 Rose Admin Terminal\n\nManage API keys and system settings.",
        ["New API Key", "List Subs", "Manage Tiers", "Status", "Logs", "Close"],
        adminMenuChannel);
    
    llSetTimerEvent(60.0); // Auto-close menu after 60 seconds
}

integer isAuthorized(key user)
{
    // Check if user is in TERMINAL_OWNERS list
    string userUUID = llToLower((string)user);
    integer i;
    for (i = 0; i < llGetListLength(TERMINAL_OWNERS); i++)
    {
        if (llToLower(llList2String(TERMINAL_OWNERS, i)) == userUUID)
        {
            return TRUE;
        }
    }
    
    return FALSE;
}

sendSystemRequest(string endpoint, string method, string json, key requestingUser)
{
    if (SUBSCRIBER_KEY == "")
    {
        llOwnerSay("❌ ERROR: SUBSCRIBER_KEY not configured");
        return;
    }
    
    string url = API_ENDPOINT + endpoint;
    
    list params = [HTTP_METHOD, method,
                   HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY,
                   HTTP_BODY_MAXLENGTH, 16000];
    
    // Always set Content-Type for PUT/POST requests
    if (method == "PUT" || method == "POST")
    {
        params += [HTTP_MIMETYPE, "application/json"];
    }
    
    key http_request_id = llHTTPRequest(url, params, json);
    http_requests += [http_request_id, "system_" + method, endpoint, (string)requestingUser];
}

string extractJsonString(string json, string json_key)
{
    // Simple JSON parser for string values
    string search = "\"" + json_key + "\":\"";
    integer start = llSubStringIndex(json, search);
    if (start == -1) return "";
    
    start += llStringLength(search);
    integer end = llSubStringIndex(llGetSubString(json, start, -1), "\"");
    if (end == -1) return "";
    
    return llGetSubString(json, start, start + end - 1);
}

string escapeJson(string str)
{
    // Escape special characters for JSON
    str = llDumpList2String(llParseString2List(str, ["\\"], []), "\\\\");
    str = llDumpList2String(llParseString2List(str, ["\""], []), "\\\"");
    str = llDumpList2String(llParseString2List(str, ["\n"], []), "\\n");
    return str;
}

handleSuccessResponse(string request_type, string request_data, string body, key requestingUser)
{
    if (request_type == "system_POST" || request_type == "system_GET")
    {
        // System API response
        llOwnerSay("📋 System API Response:");
        llOwnerSay(body);
        
        // If this was a list subscribers request, cache the results
        if (llSubStringIndex(request_data, "/system/subscribers") != -1)
        {
            cached_subscribers = parseSubscriberList(body);
            if (currentMenuAction == "manage_tiers")
            {
                showSubscriberListMenu(requestingUser);
            }
        }
    }
    else if (request_type == "system_PUT")
    {
        // Update response
        llOwnerSay("✅ Update successful:");
        llOwnerSay(body);
    }
}

handleErrorResponse(integer status, string request_type, string request_data, string body)
{
    if (status == 401)
    {
        llOwnerSay("❌ Authentication failed: Invalid or insufficient API key privileges");
    }
    else if (status == 403)
    {
        llOwnerSay("❌ Access forbidden: " + body);
    }
    else if (status == 429)
    {
        llOwnerSay("❌ Credit limit exceeded: " + body);
    }
    else
    {
        llOwnerSay("HTTP Error " + (string)status + ": " + body);
    }
}

list parseSubscriberList(string json)
{
    // Very simple parser to extract subscriber names and IDs
    // Format: [{"id":"...","subscriberName":"...","exemptFromRateLimits":true/false}...]
    list subscribers = [];
    
    integer pos = 0;
    while (TRUE)
    {
        integer idStart = llSubStringIndex(llGetSubString(json, pos, -1), "\"id\":\"");
        if (idStart == -1) jump done;
        idStart += pos + 6;
        
        integer idEnd = llSubStringIndex(llGetSubString(json, idStart, -1), "\"");
        string id = llGetSubString(json, idStart, idStart + idEnd - 1);
        
        integer nameStart = llSubStringIndex(llGetSubString(json, idStart, -1), "\"subscriberName\":\"");
        if (nameStart == -1) jump done;
        nameStart += idStart + 18;
        
        integer nameEnd = llSubStringIndex(llGetSubString(json, nameStart, -1), "\"");
        string name = llGetSubString(json, nameStart, nameStart + nameEnd - 1);
        
        // Check for exemption status
        integer exemptStart = llSubStringIndex(llGetSubString(json, nameStart, -1), "\"exemptFromRateLimits\":");
        integer isExempt = FALSE;
        if (exemptStart != -1)
        {
            exemptStart += nameStart + 23;
            string exemptStr = llGetSubString(json, exemptStart, exemptStart + 4);
            if (exemptStr == "true")
            {
                isExempt = TRUE;
            }
        }
        
        subscribers += [id, name, isExempt];
        pos = nameStart + nameEnd + 1;
    }
    @done;
    
    return subscribers;
}

showSubscriberListMenu(key user)
{
    if (llGetListLength(cached_subscribers) == 0)
    {
        llRegionSayTo(user, 0, "No subscribers found");
        return;
    }
    
    // Remove old listener if exists
    if (subListListener != 0)
    {
        llListenRemove(subListListener);
    }
    
    subListChannel = -2000 - (integer)llFrand(9999);
    subListListener = llListen(subListChannel, "", user, "");
    
    // Build button list (max 12 buttons)
    list buttons = [];
    integer i;
    integer count = llGetListLength(cached_subscribers) / 3;
    if (count > 11) count = 11; // Leave room for "Close"
    
    for (i = 0; i < count; i++)
    {
        string name = llList2String(cached_subscribers, i * 3 + 1);
        integer isExempt = llList2Integer(cached_subscribers, i * 3 + 2);
        
        // Truncate name if needed and add exemption indicator
        if (llStringLength(name) > 20)
        {
            name = llGetSubString(name, 0, 19);
        }
        
        if (isExempt)
        {
            buttons += ["✓ " + name];
        }
        else
        {
            buttons += [name];
        }
    }
    
    buttons += ["Close"];
    
    string message = "Select subscriber to toggle rate limit exemption:\n✓ = Currently exempt";
    
    llDialog(user, message, buttons, subListChannel);
    llSetTimerEvent(60.0);
}

toggleExemption(string subscriberName, key requestingUser)
{
    // Find subscriber in cached list
    integer i;
    for (i = 0; i < llGetListLength(cached_subscribers); i += 3)
    {
        string name = llList2String(cached_subscribers, i + 1);
        if (name == subscriberName)
        {
            string id = llList2String(cached_subscribers, i);
            integer currentExempt = llList2Integer(cached_subscribers, i + 2);
            integer newExempt = !currentExempt;
            
            // Send update request
            string boolStr = "false";
            if (newExempt)
            {
                boolStr = "true";
            }
            string json = "{\"exemptFromRateLimits\":" + boolStr + "}";
            sendSystemRequest("/system/subscribers/" + id + "/exemption", "PUT", json, requestingUser);
            
            // Update cache
            cached_subscribers = llListReplaceList(cached_subscribers, [newExempt], i + 2, i + 2);
            
            llOwnerSay("Toggling exemption for " + subscriberName + " to " + (string)newExempt);
            return;
        }
    }
    
    llOwnerSay("Subscriber not found: " + subscriberName);
}

loadOwners()
{
    if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD)
    {
        llOwnerSay("Loading authorized users from " + notecardName + "...");
        notecardLine = 0;
        notecardQuery = llGetNotecardLine(notecardName, notecardLine);
    }
    else
    {
        llOwnerSay("❌ ERROR: " + notecardName + " notecard not found!");
        llOwnerSay("Please create a " + notecardName + " notecard with authorized UUIDs.");
    }
}

// ============================================
// STATE BLOCKS
// ============================================

default
{
    state_entry()
    {
        llOwnerSay("Rose Admin Terminal starting...");
        
        // Try to read SUBSCRIBER_KEY from RoseConfig if available
        if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD)
        {
            llOwnerSay("Reading SUBSCRIBER_KEY from RoseConfig...");
            notecardName = "RoseConfig";
            notecardLine = 0;
            notecardQuery = llGetNotecardLine(notecardName, notecardLine);
        }
        else
        {
            // Load terminal owners
            loadOwners();
        }
    }
    
    dataserver(key query_id, string data)
    {
        if (query_id == notecardQuery)
        {
            if (data != EOF)
            {
                // Process notecard line
                data = llStringTrim(data, STRING_TRIM);
                
                // Skip empty lines and comments
                if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    if (notecardName == "RoseConfig")
                    {
                        // Parse KEY=VALUE for SUBSCRIBER_KEY
                        integer equals = llSubStringIndex(data, "=");
                        if (equals != -1)
                        {
                            string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                            string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                            
                            if (configKey == "SUBSCRIBER_KEY")
                            {
                                SUBSCRIBER_KEY = value;
                                llOwnerSay("✅ SUBSCRIBER_KEY loaded from RoseConfig");
                            }
                            else if (configKey == "API_ENDPOINT")
                            {
                                API_ENDPOINT = value;
                                llOwnerSay("✅ API_ENDPOINT: " + API_ENDPOINT);
                            }
                        }
                    }
                    else if (notecardName == "TerminalOwners")
                    {
                        // Parse UUID (one per line)
                        // Basic UUID validation (36 chars, dashes in right places)
                        if (llStringLength(data) == 36)
                        {
                            TERMINAL_OWNERS += [llToLower(data)];
                            llOwnerSay("✅ Added authorized user: " + data);
                        }
                    }
                }
                
                // Read next line
                ++notecardLine;
                notecardQuery = llGetNotecardLine(notecardName, notecardLine);
            }
            else
            {
                // Finished reading notecard
                if (notecardName == "RoseConfig")
                {
                    // Now load terminal owners
                    notecardName = "TerminalOwners";
                    loadOwners();
                }
                else if (notecardName == "TerminalOwners")
                {
                    if (llGetListLength(TERMINAL_OWNERS) == 0)
                    {
                        llOwnerSay("⚠️ WARNING: No authorized users loaded from " + notecardName);
                        llOwnerSay("Add UUIDs (one per line) to the notecard.");
                    }
                    
                    if (SUBSCRIBER_KEY == "")
                    {
                        llOwnerSay("❌ ERROR: SUBSCRIBER_KEY not configured");
                        llOwnerSay("Add 'SUBSCRIBER_KEY=your-key-here' to RoseConfig notecard.");
                    }
                    else
                    {
                        llOwnerSay("✅ Rose Admin Terminal initialized and ready!");
                        llOwnerSay("Touch to access admin functions.");
                    }
                }
            }
        }
    }
    
    touch_start(integer num_detected)
    {
        key toucher = llDetectedKey(0);
        
        if (!isAuthorized(toucher))
        {
            llRegionSayTo(toucher, 0, "⛔ Access denied - Not authorized");
            return;
        }
        
        showAdminMenu(toucher);
    }
    
    timer()
    {
        // Clean up menu listeners
        if (adminMenuListener != 0)
        {
            llListenRemove(adminMenuListener);
            adminMenuListener = 0;
        }
        if (adminTextboxListener != 0)
        {
            llListenRemove(adminTextboxListener);
            adminTextboxListener = 0;
        }
        if (subListListener != 0)
        {
            llListenRemove(subListListener);
            subListListener = 0;
        }
        llSetTimerEvent(0.0);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == adminMenuChannel)
        {
            if (message == "New API Key")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                
                // Remove old textbox listener if exists
                if (adminTextboxListener != 0)
                {
                    llListenRemove(adminTextboxListener);
                }
                
                // Prompt for subscriber name with unique channel
                adminTextboxChannel = (integer)("0x" + llGetSubString((string)llGenerateKey(), 0, 7));
                adminTextboxListener = llListen(adminTextboxChannel, "", id, "");
                llTextBox(id, "Enter subscriber name:", adminTextboxChannel);
                llSetTimerEvent(60.0); // Reset timer for textbox
            }
            else if (message == "List Subs")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                sendSystemRequest("/system/subscribers", "GET", "", id);
            }
            else if (message == "Manage Tiers")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                currentMenuAction = "manage_tiers";
                sendSystemRequest("/system/subscribers", "GET", "", id);
            }
            else if (message == "Status")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                sendSystemRequest("/system/status", "GET", "", id);
            }
            else if (message == "Logs")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                sendSystemRequest("/system/logs?count=10", "GET", "", id);
            }
            else if (message == "Close")
            {
                // Close admin menu
                if (adminMenuListener != 0)
                {
                    llListenRemove(adminMenuListener);
                    adminMenuListener = 0;
                }
                llSetTimerEvent(0.0);
            }
        }
        else if (channel == subListChannel)
        {
            if (message == "Close")
            {
                if (subListListener != 0)
                {
                    llListenRemove(subListListener);
                    subListListener = 0;
                }
                llSetTimerEvent(0.0);
                return;
            }
            
            // Remove ✓ prefix if present
            string subscriberName = message;
            if (llGetSubString(message, 0, 1) == "✓ ")
            {
                subscriberName = llGetSubString(message, 2, -1);
            }
            
            toggleExemption(subscriberName, id);
            
            // Refresh the menu after a brief delay
            llSleep(1.0);
            showSubscriberListMenu(id);
        }
        else if (channel == adminTextboxChannel && adminTextboxListener != 0)
        {
            // Got subscriber name, generate key
            llListenRemove(adminTextboxListener);
            adminTextboxListener = 0;
            llSetTimerEvent(0.0);
            
            string subscriberName = escapeJson(message);
            string json = "{" +
                "\"subscriberId\":\"" + (string)llGenerateKey() + "\"," +
                "\"subscriberName\":\"" + subscriberName + "\"," +
                "\"subscriptionLevel\":1," +
                "\"notes\":\"Created via Admin Terminal\"" +
                "}";
            
            sendSystemRequest("/system/subscribers/generate-key", "POST", json, id);
        }
    }
    
    http_response(key http_request_id, integer status, list metadata, string body)
    {
        // Find the request in our tracking list
        integer idx = llListFindList(http_requests, [http_request_id]);
        if (idx == -1)
        {
            // Not our request
            return;
        }
        
        string request_type = llList2String(http_requests, idx + 1);
        string request_data = llList2String(http_requests, idx + 2);
        key requestingUser = (key)llList2String(http_requests, idx + 3);
        
        // Remove from tracking list
        http_requests = llDeleteSubList(http_requests, idx, idx + 3);
        
        if (status == 200)
        {
            handleSuccessResponse(request_type, request_data, body, requestingUser);
        }
        else
        {
            handleErrorResponse(status, request_type, request_data, body);
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD || 
                llGetInventoryType("TerminalOwners") == INVENTORY_NOTECARD)
            {
                llOwnerSay("🔄 Configuration updated, reloading...");
                llResetScript();
            }
        }
    }
}
