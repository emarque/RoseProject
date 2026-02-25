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

// Available menu items/actions (configurable)
list AVAILABLE_ACTIONS = ["Coffee", "Tea", "Water", "Hot Chocolate", "Espresso"];
string current_activity = "";  // Current activity from wander script

// Link message numbers
integer LINK_SENSOR_DETECTED = 1000;
integer LINK_CHAT_MESSAGE = 1001;
integer LINK_SPEAK = 1002;
integer LINK_ANIMATION = 1003;
integer LINK_HTTP_REQUEST = 1004;
integer LINK_ACTIVITY_UPDATE = 2001;  // Activity name from wander script
integer LINK_ACTION_EXECUTE = 2002;    // Execute action from chat response
integer LINK_TRAINING_START = 3000;
integer LINK_TRAINING_ACTIVE = 3002;  // Training mode is active
integer LINK_TRAINING_COMPLETE = 3001;
integer LINK_TRAINING_CANCEL = 3003;  // Training mode cancelled

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

// Subscriber management state
integer subListChannel;
integer subListListener;
list cached_subscribers = [];
string currentMenuAction = "";

// Confirmation dialog state
string pending_action = "";        // Action awaiting confirmation
string pending_action_data = "";   // Associated data
key pending_action_user = NULL_KEY;
integer confirmation_listener = 0;
integer confirmation_channel = 0;

// Training mode state
integer training_mode_active = FALSE;
key training_mode_user = NULL_KEY;

// Debug mode state
integer DEBUG = FALSE;
integer debugMenuChannel;
integer debugMenuListener;

// Debug link message constants
integer LINK_DEBUG_STATUS_REQUEST = 9000;
integer LINK_DEBUG_STATUS_RESPONSE = 9001;

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
        ["New API Key", "List Subs", "Manage Tiers", "Status", "Logs", "Close"],
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

showConfirmationDialog(key user, string action, string description, string data)
{
    // Clean up any existing confirmation listener
    if (confirmation_listener != 0)
    {
        llListenRemove(confirmation_listener);
    }
    
    pending_action = action;
    pending_action_data = data;
    pending_action_user = user;
    confirmation_channel = -1000 - (integer)llFrand(99999);
    confirmation_listener = llListen(confirmation_channel, "", user, "");
    
    llDialog(user, 
        "⚠️ " + description + "\n\nAre you sure?",
        ["✓ Yes", "✗ Cancel"],
        confirmation_channel);
    
    llSetTimerEvent(30.0); // Auto-cancel after 30s
}

executeConfirmedAction(string action, string data)
{
    key user = pending_action_user;
    
    if (action == "TRAINING_MODE")
    {
        // Start training wizard
        llRegionSayTo(user, 0, "Starting training mode...");
        llMessageLinked(LINK_SET, LINK_TRAINING_START, data, user);
    }
    else if (action == "NEW_API_KEY")
    {
        // Remove old textbox listener if exists
        if (adminTextboxListener != 0)
        {
            llListenRemove(adminTextboxListener);
        }
        
        // Prompt for subscriber name with unique channel
        adminTextboxChannel = (integer)("0x" + llGetSubString((string)llGenerateKey(), 0, 7));
        adminTextboxListener = llListen(adminTextboxChannel, "", user, "");
        llTextBox(user, "Enter subscriber name:", adminTextboxChannel);
        llSetTimerEvent(60.0); // Reset timer for textbox
    }
    else if (action == "LIST_SUBS")
    {
        sendSystemRequest("/system/subscribers", "GET", "");
    }
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
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16000],
        "");
    
    // Store toucher info with request for thread-safety
    http_requests += [http_request_id, "key_check", (string)toucher + "|" + name];
}

sendSystemRequest(string endpoint, string method, string json)
{
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
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16000],
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
    
    // Add current activity if available
    if (current_activity != "")
    {
        json += ",\"currentActivity\":\"" + escapeJson(current_activity) + "\"";
    }
    
    // Add available actions
    if (llGetListLength(AVAILABLE_ACTIONS) > 0)
    {
        json += ",\"availableActions\":[";
        integer i;
        for (i = 0; i < llGetListLength(AVAILABLE_ACTIONS); i++)
        {
            if (i > 0) json += ",";
            json += "\"" + llList2String(AVAILABLE_ACTIONS, i) + "\"";
        }
        json += "]";
    }
    
    json += "}";
    
    key http_request_id = llHTTPRequest(url,
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16000],
        json);
    
    http_requests += [http_request_id, "chat", avatarKey];
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

toggleExemption(string subscriberName)
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
            sendSystemRequest("/system/subscribers/" + id + "/exemption", "PUT", json);
            
            // Update cache
            cached_subscribers = llListReplaceList(cached_subscribers, [newExempt], i + 2, i + 2);
            
            llOwnerSay("Toggling exemption for " + subscriberName + " to " + (string)newExempt);
            return;
        }
    }
    
    llOwnerSay("Subscriber not found: " + subscriberName);
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
        
        // If this was a list subscribers request, cache the results
        if (llSubStringIndex(request_data, "/system/subscribers") != -1)
        {
            cached_subscribers = parseSubscriberList(body);
            if (currentMenuAction == "manage_tiers")
            {
                // Show subscriber list menu to the requesting user
                // Note: We need to track the requesting user; for now use owner as fallback
                // In a full implementation, store the requesting user with the HTTP request
                key admin = llGetOwner();
                showSubscriberListMenu(admin);
                currentMenuAction = ""; // Reset action
            }
        }
    }
    else if (request_type == "system_PUT")
    {
        // Update response
        llOwnerSay("✅ Update successful:");
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
        
        // Parse and execute actions if present
        parseAndExecuteActions(body);
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

parseAndExecuteActions(string json)
{
    // Look for actions array in JSON response
    // Format: "actions":[{"type":"give","target":"Coffee","parameters":null}]
    integer actionsStart = llSubStringIndex(json, "\"actions\":");
    if (actionsStart == -1) return;  // No actions
    
    // Check if it's null - skip past "\"actions\":" (10 chars) to check value
    string afterActions = llGetSubString(json, actionsStart + 10, actionsStart + 14);
    if (afterActions == "null") return;
    
    // Find the array start
    integer arrayStart = llSubStringIndex(llGetSubString(json, actionsStart, -1), "[");
    if (arrayStart == -1) return;
    arrayStart += actionsStart;
    
    // Find the array end
    integer arrayEnd = llSubStringIndex(llGetSubString(json, arrayStart, -1), "]");
    if (arrayEnd == -1) return;
    
    string actionsArray = llGetSubString(json, arrayStart + 1, arrayStart + arrayEnd - 1);
    
    // Parse each action in the array
    // Simple parser - look for objects between {}
    integer pos = 0;
    while (TRUE)
    {
        integer objStart = llSubStringIndex(llGetSubString(actionsArray, pos, -1), "{");
        if (objStart == -1) return;  // No more actions
        objStart += pos;
        
        integer objEnd = llSubStringIndex(llGetSubString(actionsArray, objStart, -1), "}");
        if (objEnd == -1) return;
        objEnd += objStart;
        
        string actionObj = llGetSubString(actionsArray, objStart, objEnd);
        
        // Extract action type and target
        string actionType = extractJsonString(actionObj, "type");
        string actionTarget = extractJsonString(actionObj, "target");
        
        if (actionType != "")
        {
            executeAction(actionType, actionTarget);
        }
        
        pos = objEnd + 1;
        if (pos >= llStringLength(actionsArray)) return;
    }
}

executeAction(string actionType, string actionTarget)
{
    // Send action to appropriate handler script
    string actionMsg = actionType + "|" + actionTarget;
    
    if (actionType == "give")
    {
        // Give an item to the requester
        llMessageLinked(LINK_SET, LINK_ACTION_EXECUTE, "GIVE:" + actionTarget, NULL_KEY);
        llOwnerSay("Action: Give " + actionTarget);
    }
    else if (actionType == "navigate")
    {
        // Navigate to a location
        llMessageLinked(LINK_SET, LINK_ACTION_EXECUTE, "NAVIGATE:" + actionTarget, NULL_KEY);
        llOwnerSay("Action: Navigate to " + actionTarget);
    }
    else if (actionType == "gesture")
    {
        // Perform a gesture/animation
        llMessageLinked(LINK_SET, LINK_ANIMATION, actionTarget, NULL_KEY);
        llOwnerSay("Action: Gesture " + actionTarget);
    }
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
                        else if (configKey == "AVAILABLE_ACTIONS")
                        {
                            // Parse comma-separated list of actions
                            AVAILABLE_ACTIONS = llParseString2List(value, [","], []);
                            // Trim whitespace from each item
                            integer i;
                            list trimmed = [];
                            for (i = 0; i < llGetListLength(AVAILABLE_ACTIONS); i++)
                            {
                                string item = llStringTrim(llList2String(AVAILABLE_ACTIONS, i), STRING_TRIM);
                                if (item != "") trimmed += [item];
                            }
                            AVAILABLE_ACTIONS = trimmed;
                            llOwnerSay("✅ AVAILABLE_ACTIONS: " + llDumpList2String(AVAILABLE_ACTIONS, ", "));
                        }
                        else if (configKey == "DEBUG")
                        {
                            if (llToUpper(value) == "TRUE")
                            {
                                DEBUG = TRUE;
                                llOwnerSay("✅ DEBUG mode: ENABLED");
                            }
                            else
                            {
                                DEBUG = FALSE;
                            }
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
                
                // Set up debug menu listener if DEBUG is enabled
                if (DEBUG)
                {
                    debugMenuChannel = -9876;
                    debugMenuListener = llListen(debugMenuChannel, "", NULL_KEY, "");
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
        
        // If training mode is active, don't show menu to anyone
        // (Training script will handle the training user's touches)
        if (training_mode_active)
        {
            // Ignore all touches during training - Training script handles them
            return;
        }
        
        // If DEBUG mode is enabled, show debug menu
        if (DEBUG)
        {
            llDialog(toucher, "🔍 DEBUG Menu\n\nDiagnostic tools for troubleshooting.", 
                     ["Status Report"], debugMenuChannel);
            return;
        }
        
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
        if (subListListener != 0)
        {
            llListenRemove(subListListener);
            subListListener = 0;
        }
        
        // Clean up confirmation listener and state
        if (confirmation_listener != 0)
        {
            llListenRemove(confirmation_listener);
            confirmation_listener = 0;
            
            // Notify user if there was a pending action
            if (pending_action_user != NULL_KEY && pending_action != "")
            {
                llRegionSayTo(pending_action_user, 0, "⏱️ Confirmation timed out.");
            }
            
            pending_action = "";
            pending_action_data = "";
            pending_action_user = NULL_KEY;
        }
        
        llSetTimerEvent(0.0);
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (channel == debugMenuChannel)
        {
            if (message == "Status Report")
            {
                llOwnerSay("[Main] Requesting status from Manager...");
                // Send status request to WPManager
                llMessageLinked(LINK_SET, LINK_DEBUG_STATUS_REQUEST, "", NULL_KEY);
            }
        }
        else if (channel == confirmation_channel)
        {
            llListenRemove(confirmation_listener);
            confirmation_listener = 0;
            llSetTimerEvent(0.0);
            
            if (message == "✓ Yes")
            {
                executeConfirmedAction(pending_action, pending_action_data);
            }
            else
            {
                llRegionSayTo(id, 0, "Action cancelled.");
            }
            
            pending_action = "";
            pending_action_data = "";
            pending_action_user = NULL_KEY;
        }
        else if (channel == adminMenuChannel)
        {
            if (message == "New API Key")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                
                showConfirmationDialog(id, "NEW_API_KEY", "Generate a new subscriber API key?", "");
            }
            else if (message == "List Subs")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                showConfirmationDialog(id, "LIST_SUBS", "Retrieve subscriber list from system API?", "");
            }
            else if (message == "Manage Tiers")
            {
                if (SUBSCRIBER_KEY == "")
                {
                    llRegionSayTo(id, 0, "❌ Error: SUBSCRIBER_KEY not configured");
                    return;
                }
                currentMenuAction = "manage_tiers";
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
                
                showConfirmationDialog(id, "TRAINING_MODE", "This will pause navigation and enter training mode.", name);
                
                // Clean up user menu listener
                if (userMenuListener != 0)
                {
                    llListenRemove(userMenuListener);
                    userMenuListener = 0;
                }
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
            
            toggleExemption(subscriberName);
            
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
                "\"notes\":\"Created via LSL admin menu\"" +
                "}";
            
            sendSystemRequest("/system/subscribers/generate-key", "POST", json);
        }
    }
    
    link_message(integer sender, integer num, string msg, key link_id)
    {
        // Handle training mode state changes
        if (num == LINK_TRAINING_ACTIVE)
        {
            training_mode_active = TRUE;
            training_mode_user = link_id;
        }
        else if (num == LINK_TRAINING_COMPLETE || num == LINK_TRAINING_CANCEL)
        {
            training_mode_active = FALSE;
            training_mode_user = NULL_KEY;
        }
        else if (num == LINK_SENSOR_DETECTED)
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
        else if (num == LINK_ACTIVITY_UPDATE)
        {
            // Activity update from wander script: msg format is "activity_name"
            current_activity = msg;
        }
        else if (num == LINK_DEBUG_STATUS_RESPONSE)
        {
            // Status report from WPManager
            // Split by pipe separator and display each line
            list lines = llParseString2List(msg, ["|"], []);
            integer i;
            for (i = 0; i < llGetListLength(lines); i++)
            {
                llOwnerSay(llList2String(lines, i));
            }
        }
    }
    
    http_response(key http_request_id, integer status, list metadata, string body)
    {
        // Find the request in our tracking list
        integer idx = llListFindList(http_requests, [http_request_id]);
        if (idx == -1)
        {
            // Silently ignore - likely from another script in linkset
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
