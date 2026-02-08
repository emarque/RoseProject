// RoseReceptionist_Main.lsl
// Main control script for Rose Receptionist system
// Handles HTTP communication with backend server and coordinates other scripts

string API_ENDPOINT = "";
list OWNER_UUIDS = [];
string API_KEY = "rose-api-key-12345"; // Change this in production
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

// State
key current_http_request;

default
{
    state_entry()
    {
        llOwnerSay("Rose Receptionist Main Script starting...");
        
        // Read configuration from notecard
        if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD)
        {
            readConfig();
        }
        else
        {
            llOwnerSay("Warning: RoseConfig notecard not found. Using defaults.");
            llOwnerSay("Please create a RoseConfig notecard with API_ENDPOINT and OWNER_UUID settings.");
        }
        
        llOwnerSay("Rose Receptionist is active!");
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
        else
        {
            llOwnerSay("HTTP Error " + (string)status + ": " + body);
            // Could implement retry logic here
        }
    }
}

readConfig()
{
    // This is a simplified version - full implementation would use dataserver event
    llOwnerSay("Note: Config reading not fully implemented in this version.");
    llOwnerSay("Set API_ENDPOINT in script directly or via touch menu.");
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
         HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY,
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
         HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    http_requests += [request_id, "chat", avatarKey];
}

handleSuccessResponse(string request_type, string body)
{
    if (request_type == "arrival")
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
