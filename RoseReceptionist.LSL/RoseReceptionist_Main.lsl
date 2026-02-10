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

list OWNER_UUIDS = [];
list OWNER_NAMES = [];
integer GREETING_RANGE = 10;
string RECEPTIONIST_NAME = "Rose";

// Link message numbers
integer LINK_SENSOR_DETECTED = 1000;
integer LINK_CHAT_MESSAGE = 1001;
integer LINK_SPEAK = 1002;
integer LINK_ANIMATION = 1003;
integer LINK_HTTP_REQUEST = 1004;
integer LINK_TRAINING_START = 3000;

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

// User menu state
integer userMenuChannel;
integer userMenuListener;

// State
key current_http_request;

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
        "🔧 Rose Admin Menu\n\nManage API keys and view system status.",
        ["New API Key", "List Subs", "Status", "Logs", "Close"],
        adminMenuChannel);
    
    llSetTimerEvent(60.0); // Auto-close menu after 60 seconds
}

showUserMenu(key user, string userName)
{
    // Remove old menu listener if exists
    if (userMenuListener != 0)
    {
        llListenRemove(userMenuListener);
    }
    
    userMenuChannel = -1000 - (integer)llFrand(9999);
    userMenuListener = llListen(userMenuChannel, "", user, "");
    
    llDialog(user, 
        "Hi! I'm " + RECEPTIONIST_NAME + ". How can I help you?",
        ["Get Attention", "Training Mode", "Cancel"],
        userMenuChannel);
    
    llSetTimerEvent(60.0); // Auto-close menu after 60 seconds
}

integer isAdmin(key user)
{
    // Check if user is owner
    if (user == llGetOwner())
    {
        return TRUE;
    }
    
    // Check if user is in OWNER_UUIDS list
    // Convert to lowercase for case-insensitive comparison
    string userUUID = llToLower((string)user);
    integer i;
    for (i = 0; i < llGetListLength(OWNER_UUIDS); i++)
    {
        if (llToLower(llList2String(OWNER_UUIDS, i)) == userUUID)
        {
            return TRUE;
        }
    }
    
    return FALSE;
}

checkMasterKeyAndShowMenu(key toucher, string name)
{
    if (SUBSCRIBER_KEY == "")
    {
        // No key configured, show user menu
        showUserMenu(toucher, name);
        return;
    }
    
    // Try to access a system endpoint to verify master key
    string url = API_ENDPOINT + "/system/status";
    
    key http_request_id = llHTTPRequest(url,
        [HTTP_METHOD, "GET",
         HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        "");
    
    // Store toucher info with request for thread-safety
    http_requests += [http_request_id, "key_check", (string)toucher + "|" + name];
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
    
    key http_request_id = llHTTPRequest(url, params, json);
    http_requests += [http_request_id, "system_" + method, endpoint];
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
    
    key http_request_id = llHTTPRequest(url,
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    http_requests += [http_request_id, "arrival", avatarKey];
}

sendChatRequest(string avatarKey, string avatarName, string message, string sessionId, string transcript)
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
        "\"sessionId\":\"" + sessionId + "\"";
    
    // Add transcript if provided
    if (transcript != "")
    {
        json += ",\"transcript\":\"" + escapeJson(transcript) + "\"";
    }
    
    json += "}";
    
    key http_request_id = llHTTPRequest(url,
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    http_requests += [http_request_id, "chat", avatarKey];
}

handleSuccessResponse(string request_type, string request_data, string body)
{
    if (request_type == "key_check")
    {
        // Successfully accessed system endpoint - we have master key
        // Extract toucher info from request_data
        list parts = llParseString2List(request_data, ["|"], []);
        key toucher = (key)llList2String(parts, 0);
        showAdminMenu(toucher);
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

handleErrorResponse(integer status, string request_type, string request_data, string body)
{
    if (request_type == "key_check")
    {
        // Extract toucher info from request_data
        list parts = llParseString2List(request_data, ["|"], []);
        key toucher = (key)llList2String(parts, 0);
        string name = llList2String(parts, 1);
        
        if (status == 401)
        {
            // Not a master key, show user menu instead
            showUserMenu(toucher, name);
        }
        else
        {
            // Other error, default to user menu
            llRegionSayTo(toucher, 0, "⚠️ Could not verify API key, showing user menu");
            showUserMenu(toucher, name);
        }
    }
    else if (status == 401)
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
                            // Trim whitespace and store UUID
                            value = llStringTrim(value, STRING_TRIM);
                            if (value != "" && value != "00000000-0000-0000-0000-000000000000")
                            {
                                OWNER_UUIDS += [llToLower(value)];
                                llOwnerSay("✅ Added owner: " + value);
                            }
                        }
                        else if (llSubStringIndex(configKey, "OWNER_UUID_") == 0)
                        {
                            // Support OWNER_UUID_1, OWNER_UUID_2, etc.
                            // Trim whitespace and store UUID
                            value = llStringTrim(value, STRING_TRIM);
                            if (value != "" && value != "00000000-0000-0000-0000-000000000000")
                            {
                                OWNER_UUIDS += [llToLower(value)];
                                integer ownerNum = (integer)llGetSubString(configKey, 11, -1);
                                llOwnerSay("✅ Owner #" + (string)ownerNum + " UUID: " + value);
                            }
                        }
                        else if (llSubStringIndex(configKey, "OWNER_NAME_") == 0)
                        {
                            // Support OWNER_NAME_1, OWNER_NAME_2, etc.
                            OWNER_NAMES += [value];
                            integer ownerNum = (integer)llGetSubString(configKey, 11, -1);
                            llOwnerSay("✅ Owner #" + (string)ownerNum + " name: " + value);
                        }
                        else if (configKey == "RECEPTIONIST_NAME")
                        {
                            RECEPTIONIST_NAME = value;
                            llOwnerSay("✅ RECEPTIONIST_NAME: " + RECEPTIONIST_NAME);
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
        key toucher = llDetectedKey(0);
        string name = llDetectedName(0);
        
        // Check what kind of key we have, then show appropriate menu
        checkMasterKeyAndShowMenu(toucher, name);
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
        if (userMenuListener != 0)
        {
            llListenRemove(userMenuListener);
            userMenuListener = 0;
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
                sendSystemRequest("/system/subscribers", "GET", "");
            }
            else if (message == "Status")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                sendSystemRequest("/system/status", "GET", "");
            }
            else if (message == "Logs")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                sendSystemRequest("/system/logs?count=10", "GET", "");
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
            // Removed "Credits" option until functionality is implemented
        }
        else if (channel == userMenuChannel)
        {
            if (message == "Get Attention")
            {
                // Trigger attention-getting behavior
                llRegionSayTo(id, 0, "You have my attention! How can I help you?");
                llMessageLinked(LINK_SET, LINK_ANIMATION, "wave", NULL_KEY);
                
                // Start conversation
                llMessageLinked(LINK_SET, LINK_CHAT_MESSAGE, (string)id + "|" + name + "|Hello|", NULL_KEY);
                
                // Clean up listener
                if (userMenuListener != 0)
                {
                    llListenRemove(userMenuListener);
                    userMenuListener = 0;
                }
                llSetTimerEvent(0.0);
            }
            else if (message == "Training Mode")
            {
                // Only allow training for owners
                if (!isAdmin(id))
                {
                    llRegionSayTo(id, 0, "❌ Training mode is only available to authorized owners");
                    return;
                }
                
                // Start training wizard
                llRegionSayTo(id, 0, "Starting training mode...");
                llMessageLinked(LINK_SET, LINK_TRAINING_START, name, id);
                
                // Clean up listener
                if (userMenuListener != 0)
                {
                    llListenRemove(userMenuListener);
                    userMenuListener = 0;
                }
                llSetTimerEvent(0.0);
            }
            else if (message == "Cancel")
            {
                // Just close menu
                if (userMenuListener != 0)
                {
                    llListenRemove(userMenuListener);
                    userMenuListener = 0;
                }
                llSetTimerEvent(0.0);
            }
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
    
    link_message(integer sender, integer num, string msg, key link_id)
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
            // Chat message: msg format is "avatarKey|avatarName|message|sessionId|transcript"
            list parts = llParseString2List(msg, ["|"], []);
            string avatarKey = llList2String(parts, 0);
            string avatarName = llList2String(parts, 1);
            string message = llList2String(parts, 2);
            string sessionId = llList2String(parts, 3);
            string transcript = "";
            
            // Check if transcript is included (5th parameter)
            if (llGetListLength(parts) >= 5)
            {
                transcript = llList2String(parts, 4);
            }
            
            sendChatRequest(avatarKey, avatarName, message, sessionId, transcript);
        }
    }
    
    http_response(key http_request_id, integer status, list metadata, string body)
    {
        // Find the request in our tracking list
        integer idx = llListFindList(http_requests, [http_request_id]);
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
            handleSuccessResponse(request_type, request_data, body);
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
            if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD)
            {
                llOwnerSay("🔄 Configuration updated, reloading...");
                llResetScript();
            }
        }
    }
}
