// [WPP]WPReporter.lsl
// Activity Reporter - Tracks and reports activities via API

// CONFIGURATION
// SUBSCRIBER_KEY is now read from RoseConfig.txt notecard
// Get your subscriber key from your Rose Receptionist dashboard
string API_ENDPOINT = "https://rosercp.pantherplays.com/api";
string SUBSCRIBER_KEY = "your-subscriber-key-here";  // Will be loaded from RoseConfig.txt

// Debug mode
integer DEBUG = FALSE;  // Will be loaded from RoseConfig.txt

string SHIFT_START_TIME = "09:00";
string SHIFT_END_TIME = "17:00";
string DAILY_REPORT_TIME = "17:05";

// Link messages
integer LINK_ACTIVITY_START = 3010;    // Waypoint->Reporter: Activity started (msg=name, id=type|duration)
integer LINK_ACTIVITY_COMPLETE = 3011; // Waypoint->Reporter: Activity completed (msg=name)
integer LINK_ACTIVITY_QUERY = 3012;    // Other->Reporter: Get current activity

// Config reading
string notecardName = "RoseConfig";
key notecardQuery;
integer notecardLine = 0;

// Debug output function
debugSay(string msg)
{
    if (DEBUG)
    {
        llOwnerSay("[Reporter] " + msg);
    }
}

// STATE VARIABLES
string current_activity_name = "idle";
string current_activity_id = "";
integer last_report_day = -1;

// HTTP error tracking
integer last_429_time = 0;
integer error_429_count = 0;

// Activity batching
list pending_activities = []; // [name, type, duration, timestamp, ...]
integer BATCH_SIZE = 5;
float BATCH_INTERVAL = 300.0; // 5 minutes
integer last_batch_time = 0;
list tracked_activities = []; // Track unique activities only

// Check if activity is new for batching
integer isNewActivity(string name)
{
    integer i;
    for (i = 0; i < llGetListLength(tracked_activities); i++)
    {
        if (llList2String(tracked_activities, i) == name)
        {
            return FALSE;
        }
    }
    return TRUE;
}

// Queue activity for batch reporting
queueActivity(string name, string type, integer duration)
{
    if (!isNewActivity(name))
    {
        return;
    }
    
    tracked_activities += [name];
    pending_activities += [name, type, duration, llGetUnixTime()];
    
    // Batch send if enough queued or time elapsed
    if (llGetListLength(pending_activities) / 4 >= BATCH_SIZE || 
        llGetUnixTime() - last_batch_time > BATCH_INTERVAL)
    {
        sendActivityBatch();
    }
}

// Send batched activities to API
sendActivityBatch()
{
    if (llGetListLength(pending_activities) == 0) return;
    
    // Build JSON array
    string json = "[";
    integer i;
    for (i = 0; i < llGetListLength(pending_activities); i += 4)
    {
        if (i > 0) json += ",";
        json += "{\"name\":\"" + llList2String(pending_activities, i) + "\",";
        json += "\"type\":\"" + llList2String(pending_activities, i + 1) + "\",";
        json += "\"duration\":" + (string)llList2Integer(pending_activities, i + 2) + ",";
        json += "\"timestamp\":" + (string)llList2Integer(pending_activities, i + 3) + "}";
    }
    json += "]";
    
    // Send batch
    key http_request_id = llHTTPRequest(API_ENDPOINT + "/activities/batch",
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    pending_activities = [];
    tracked_activities = []; // Clear to prevent unbounded memory growth
    last_batch_time = llGetUnixTime();
}

// Complete activity via API
completeActivity(string activityId)
{
    if (activityId == "") return;
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/" + activityId + "/complete",
        [HTTP_METHOD, "PUT",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY],
        "{}"
    );
}

// Get current activity via API
getCurrentActivity()
{
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/current",
        [HTTP_METHOD, "GET",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY],
        ""
    );
}

// Generate daily report
generateDailyReport()
{
    string today = llGetDate();
    
    string json = "{\"reportDate\":\"" + today + "T00:00:00Z\",\"shiftStart\":\"" + today + "T" + SHIFT_START_TIME + ":00Z\",\"shiftEnd\":\"" + today + "T" + SHIFT_END_TIME + ":00Z\"}";
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/daily",
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)SUBSCRIBER_KEY],
        json
    );
    
    debugSay("Daily report: " + today);
}

// MAIN STATE
default
{
    state_entry()
    {
        debugSay("Reporter ready");
        last_batch_time = llGetUnixTime();
        
        // Read config from notecard
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD)
        {
            debugSay("Reading config...");
            notecardLine = 0;
            notecardQuery = llGetNotecardLine(notecardName, notecardLine);
        }
        else
        {
            debugSay("No RoseConfig found, using default SUBSCRIBER_KEY");
            // Warn if SUBSCRIBER_KEY is not configured
            if (SUBSCRIBER_KEY == "your-subscriber-key-here")
            {
                llOwnerSay("⚠️ WARNING: SUBSCRIBER_KEY not configured!");
                llOwnerSay("Add SUBSCRIBER_KEY to RoseConfig notecard");
                llOwnerSay("All API calls will fail with HTTP 401");
            }
        }
    }
    
    timer()
    {
        // Check if it's time for daily report
        string currentTime = llGetTimestamp();
        integer day = (integer)llGetSubString(currentTime, 8, 9);
        integer hour = (integer)llGetSubString(currentTime, 11, 12);
        integer minute = (integer)llGetSubString(currentTime, 14, 15);
        
        list reportTimeParts = llParseString2List(DAILY_REPORT_TIME, [":"], []);
        integer reportHour = llList2Integer(reportTimeParts, 0);
        integer reportMinute = llList2Integer(reportTimeParts, 1);
        
        if (hour == reportHour && minute == reportMinute && day != last_report_day)
        {
            last_report_day = day;
            generateDailyReport();
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_ACTIVITY_START)
        {
            // Activity starting - msg=name, id=type|duration
            current_activity_name = msg;
            
            // Parse type|duration from id
            string idStr = (string)id;
            integer pipePos = llSubStringIndex(idStr, "|");
            if (pipePos != -1)
            {
                string type = llGetSubString(idStr, 0, pipePos - 1);
                integer duration = (integer)llGetSubString(idStr, pipePos + 1, -1);
                
                // Queue for batch reporting
                queueActivity(msg, type, duration);
            }
        }
        else if (num == LINK_ACTIVITY_COMPLETE)
        {
            // Activity completed - msg=name
            if (current_activity_id != "")
            {
                completeActivity(current_activity_id);
                current_activity_id = "";
            }
            current_activity_name = "idle";
        }
        else if (num == LINK_ACTIVITY_QUERY)
        {
            // Someone asking for current activity
            getCurrentActivity();
        }
    }
    
    http_response(key http_request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            // Success - could parse response to get activity ID if needed
            // For now, just silent success
        }
        else if (status == 401)
        {
            // Unauthorized - invalid subscriber key
            llOwnerSay("⚠️ HTTP 401: Invalid subscriber key");
            llOwnerSay("Please update SUBSCRIBER_KEY in RoseConfig notecard");
            llOwnerSay("Get your subscriber key from Rose Receptionist dashboard");
        }
        else if (status == 429)
        {
            // Rate limiting
            integer now = llGetUnixTime();
            if (now - last_429_time > 300)
            {
                if (error_429_count > 1)
                {
                    debugSay("429 x" + (string)error_429_count);
                }
                else
                {
                    debugSay("429 throttled");
                }
                last_429_time = now;
                error_429_count = 0;
            }
        }
        else
        {
            // Log other HTTP errors
            debugSay("HTTP " + (string)status);
        }
    }
    
    dataserver(key query_id, string data)
    {
        if (query_id == notecardQuery)
        {
            if (data != EOF)
            {
                data = llStringTrim(data, STRING_TRIM);
                
                // Skip empty lines and comments
                if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    // Skip section headers
                    if (llGetSubString(data, 0, 0) != "[")
                    {
                        integer equals = llSubStringIndex(data, "=");
                        if (equals != -1)
                        {
                            string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                            string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                            
                            if (configKey == "SUBSCRIBER_KEY")
                            {
                                SUBSCRIBER_KEY = value;
                            }
                            else if (configKey == "DEBUG")
                            {
                                DEBUG = (value == "TRUE" || value == "true" || value == "1");
                            }
                            else if (configKey == "SHIFT_START_TIME")
                            {
                                SHIFT_START_TIME = value;
                            }
                            else if (configKey == "SHIFT_END_TIME")
                            {
                                SHIFT_END_TIME = value;
                            }
                            else if (configKey == "DAILY_REPORT_TIME")
                            {
                                DAILY_REPORT_TIME = value;
                            }
                        }
                    }
                }
                
                ++notecardLine;
                notecardQuery = llGetNotecardLine(notecardName, notecardLine);
            }
            else
            {
                // Config reading complete
                debugSay("Config loaded");
                
                // Warn if SUBSCRIBER_KEY is still not configured
                if (SUBSCRIBER_KEY == "your-subscriber-key-here")
                {
                    llOwnerSay("⚠️ WARNING: SUBSCRIBER_KEY not configured in RoseConfig!");
                    llOwnerSay("Add SUBSCRIBER_KEY to RoseConfig notecard");
                    llOwnerSay("All API calls will fail with HTTP 401");
                }
            }
        }
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }
}
