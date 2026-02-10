// RoseReceptionist_Main.lsl
// Main control script for Rose Receptionist system
// Handles HTTP communication with backend server and coordinates other scripts

// ============================================
// CONFIGURATION
// ============================================

// Your backend API URL (no trailing slash)
string API_ENDPOINT = "https://rosercp.pantherplays.com/api";

// ============================================
// DO NOT HARDCODE API_KEY HERE
// Set SUBSCRIBER_KEY in RoseConfig notecard instead
// ============================================

string SUBSCRIBER_KEY = "";
integer IS_ADMIN_MODE = FALSE;

list OWNER_UUIDS = [];
list OWNER_NAMES = [];
integer GREETING_RANGE = 10;

// Link message numbers
integer LINK_SENSOR_DETECTED = 1000;
integer LINK_CHAT_MESSAGE = 1001;
integer LINK_SPEAK = 1002;
integer LINK_ANIMATION = 1003;
integer LINK_HTTP_REQUEST = 1004;

// HTTP request tracking
list http_requests = []; // [request_id, type, data]
integer MAX_RETRIES = 3;

// Notecard reading
key notecardQuery;
integer notecardLine = 0;
string notecardName = "RoseConfig";

// Admin menu state
integer adminMenuChannel;
integer adminMenuListener;
integer adminTextboxChannel;
integer adminTextboxListener;

// State
key current_http_request;

// ============================================
// USER-DEFINED FUNCTIONS
// ============================================

checkAdminAccess()
{
    // Try to access system status endpoint to check if we have admin access
    string url = API_ENDPOINT + "/system/status";
    
    key request_id = llHTTPRequest(url,
        [HTTP_METHOD, "GET",
         HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        "");
    
    http_requests += [request_id, "admin_check", ""];
}

showAdminMenu()
{
    // Remove old menu listener if exists
    if (adminMenuListener != 0)
    {
        llListenRemove(adminMenuListener);
    }
    
    adminMenuChannel = (integer)("0x" + llGetSubString((string)llGenerateKey(), 0, 7));
    adminMenuListener = llListen(adminMenuChannel, "", llGetOwner(), "");
    
    llDialog(llGetOwner(), 
        "🔑 System Admin Menu\n\nSelect an option:",
        ["New API Key", "List Subs", "Status", "Logs"],
        adminMenuChannel);
    
    llSetTimerEvent(60.0); // Auto-close menu after 60 seconds
}

sendSystemRequest(string endpoint, string method, string json)
{
    string url = API_ENDPOINT + endpoint;
    
    list params = [HTTP_METHOD, method,
                   HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
                   HTTP_BODY_MAXLENGTH, 16384];
    
    if (json != "")
    {
        params += [HTTP_MIMETYPE, "application/json"];
    }
    
    key request_id = llHTTPRequest(url, params, json);
    http_requests += [request_id, "system_" + method, endpoint];
}

readConfig()
{
    // Deprecated: Now handled by dataserver event
    // Kept for backwards compatibility
}

sendArrivalRequest(string avatarKey, string avatarName, string location)
{
    if (API_ENDPOINT == "")
    {
        llOwnerSay("Error: API_ENDPOINT not configured");
        return;
    }
    
    string url = API_ENDPOINT + "/chat/arrival";
    string json = "{" +
        "\"avatarKey\":\"" + avatarKey + "\"," +
        "\"avatarName\":\"" + avatarName + "\"," +
        "\"location\":\"" + location + "\"" +
        "}";
    
    key request_id = llHTTPRequest(url,
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    http_requests += [request_id, "arrival", avatarKey];
}

sendChatRequest(string avatarKey, string avatarName, string message, string sessionId)
{
    if (API_ENDPOINT == "")
    {
        llOwnerSay("Error: API_ENDPOINT not configured");
        return;
    }
    
    string url = API_ENDPOINT + "/chat/message";
    string location = llGetRegionName() + " " + (string)llGetPos();
    
    string json = "{" +
        "\"avatarKey\":\"" + avatarKey + "\"," +
        "\"avatarName\":\"" + avatarName + "\"," +
        "\"message\":\"" + escapeJson(message) + "\"," +
        "\"location\":\"" + location + "\"," +
        "\"sessionId\":\"" + sessionId + "\"" +
        "}";
    
    key request_id = llHTTPRequest(url,
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    http_requests += [request_id, "chat", avatarKey];
}

handleSuccessResponse(string request_type, string body)
{
    if (request_type == "admin_check")
    {
        // Successfully accessed admin endpoint - enable admin mode
        IS_ADMIN_MODE = TRUE;
        llOwnerSay("✅ Admin mode enabled!");
        showAdminMenu();
    }
    else if (request_type == "system_POST" || request_type == "system_GET")
    {
        // System API response
        llOwnerSay("📋 System API Response:");
        llOwnerSay(body);
    }
    else if (request_type == "arrival")
    {
        // Parse arrival response
        // Expected: {"greeting":"...", "role":"...", "shouldNotifyOwners":bool, "sessionId":"..."}
        string greeting = extractJsonString(body, "greeting");
        string sessionId = extractJsonString(body, "sessionId");
        string animation = "greet";
        
        // Send greeting to chat script
        llMessageLinked(LINK_SET, LINK_SPEAK, greeting, NULL_KEY);
        
        // Trigger animation
        llMessageLinked(LINK_SET, LINK_ANIMATION, animation, NULL_KEY);
    }
    else if (request_type == "chat")
    {
        // Parse chat response
        string response = extractJsonString(body, "response");
        string animation = extractJsonString(body, "suggestedAnimation");
        
        // Send response to chat script
        llMessageLinked(LINK_SET, LINK_SPEAK, response, NULL_KEY);
        
        // Trigger animation if suggested
        if (animation != "")
        {
            llMessageLinked(LINK_SET, LINK_ANIMATION, animation, NULL_KEY);
        }
    }
}

string extractJsonString(string json, string key)
{
    // Simple JSON parser for string values
    string search = "\"" + key + "\":\"";
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

// ============================================
// STATE BLOCKS
// ============================================

default
{
    state_entry()
    {
        llOwnerSay("Rose Receptionist Main Script starting...");
        
        // Read configuration from notecard
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD)
        {
            llOwnerSay("Reading configuration from " + notecardName + "...");
            notecardLine = 0;
            notecardQuery = llGetNotecardLine(notecardName, notecardLine);
        }
        else
        {
            llOwnerSay("❌ ERROR: RoseConfig notecard not found!");
            llOwnerSay("Please create a RoseConfig notecard with SUBSCRIBER_KEY and other settings.");
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
                    // Parse KEY=VALUE
                    integer equals = llSubStringIndex(data, "=");
                    if (equals != -1)
                    {
                        string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                        
                        if (configKey == "SUBSCRIBER_KEY")
                        {
                            SUBSCRIBER_KEY = value;
                            llOwnerSay("✅ SUBSCRIBER_KEY loaded from notecard");
                        }
                        else if (configKey == "API_ENDPOINT")
                        {
                            API_ENDPOINT = value;
                            llOwnerSay("✅ API_ENDPOINT: " + API_ENDPOINT);
                        }
                        else if (configKey == "OWNER_UUID")
                        {
                            OWNER_UUIDS += [value];
                            llOwnerSay("✅ Added owner: " + value);
                        }
                        else if (llSubStringIndex(configKey, "OWNER_UUID_") == 0)
                        {
                            // Support OWNER_UUID_1, OWNER_UUID_2, etc.
                            OWNER_UUIDS += [value];
                            integer ownerNum = (integer)llGetSubString(configKey, 11, -1);
                            llOwnerSay("✅ Owner #" + (string)ownerNum + " UUID: " + value);
                        }
                        else if (llSubStringIndex(configKey, "OWNER_NAME_") == 0)
                        {
                            // Support OWNER_NAME_1, OWNER_NAME_2, etc.
                            OWNER_NAMES += [value];
                            integer ownerNum = (integer)llGetSubString(configKey, 11, -1);
                            llOwnerSay("✅ Owner #" + (string)ownerNum + " name: " + value);
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
                if (SUBSCRIBER_KEY == "")
                {
                    llOwnerSay("❌ ERROR: SUBSCRIBER_KEY not found in notecard!");
                    llOwnerSay("Add 'SUBSCRIBER_KEY=your-key-here' to RoseConfig notecard.");
                    return;
                }
                
                llOwnerSay("✅ Rose Receptionist initialized and ready!");
                llOwnerSay("Touch to access admin menu (if admin key configured).");
            }
        }
    }
    
    touch_start(integer num_detected)
    {
        // Check if toucher is owner
        key toucher = llDetectedKey(0);
        if (toucher != llGetOwner())
        {
            return;
        }
        
        // Check if we're in admin mode
        checkAdminAccess();
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
        llSetTimerEvent(0.0);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == adminMenuChannel)
        {
            if (message == "New API Key")
            {
                // Remove old textbox listener if exists
                if (adminTextboxListener != 0)
                {
                    llListenRemove(adminTextboxListener);
                }
                
                // Prompt for subscriber name with unique channel
                adminTextboxChannel = (integer)("0x" + llGetSubString((string)llGenerateKey(), 0, 7));
                adminTextboxListener = llListen(adminTextboxChannel, "", llGetOwner(), "");
                llTextBox(llGetOwner(), "Enter subscriber name:", adminTextboxChannel);
                llSetTimerEvent(60.0); // Reset timer for textbox
            }
            else if (message == "List Subs")
            {
                sendSystemRequest("/system/subscribers", "GET", "");
            }
            else if (message == "Status")
            {
                sendSystemRequest("/system/status", "GET", "");
            }
            else if (message == "Logs")
            {
                sendSystemRequest("/system/logs?count=10", "GET", "");
            }
            // Removed "Credits" option until functionality is implemented
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
                "\"notes\":\"Created via LSL admin menu\"" +
                "}";
            
            sendSystemRequest("/system/subscribers/generate-key", "POST", json);
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_SENSOR_DETECTED)
        {
            // Avatar detected: msg format is "avatarKey|avatarName|location"
            list parts = llParseString2List(msg, ["|"], []);
            string avatarKey = llList2String(parts, 0);
            string avatarName = llList2String(parts, 1);
            string location = llList2String(parts, 2);
            
            sendArrivalRequest(avatarKey, avatarName, location);
        }
        else if (num == LINK_CHAT_MESSAGE)
        {
            // Chat message: msg format is "avatarKey|avatarName|message|sessionId"
            list parts = llParseString2List(msg, ["|"], []);
            string avatarKey = llList2String(parts, 0);
            string avatarName = llList2String(parts, 1);
            string message = llList2String(parts, 2);
            string sessionId = llList2String(parts, 3);
            
            sendChatRequest(avatarKey, avatarName, message, sessionId);
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        // Find the request in our tracking list
        integer idx = llListFindList(http_requests, [request_id]);
        if (idx == -1)
        {
            llOwnerSay("Received response for unknown request");
            return;
        }
        
        string request_type = llList2String(http_requests, idx + 1);
        string request_data = llList2String(http_requests, idx + 2);
        
        // Remove from tracking list
        http_requests = llDeleteSubList(http_requests, idx, idx + 2);
        
        if (status == 200)
        {
            handleSuccessResponse(request_type, body);
        }
        else if (status == 401)
        {
            llOwnerSay("❌ Authentication failed: Invalid API key");
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
}
