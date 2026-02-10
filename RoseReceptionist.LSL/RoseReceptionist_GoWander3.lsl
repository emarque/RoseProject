// RoseReceptionist_GoWander3.lsl
// Prim-based Navigation System for Rose Receptionist
// Rose walks to sequentially numbered prims (Wander0, Wander1, etc.) and performs actions

// ============================================================================
// CONFIGURATION
// ============================================================================

string API_ENDPOINT = "https://rosercp.pantherplays.com/api";
string API_KEY = "your-api-key-here";

// Waypoint prefix (configurable via notecard)
string WAYPOINT_PREFIX = "Waypoint";

// Link messages
integer LINK_WANDERING_STATE = 2000;
integer LINK_ACTIVITY_UPDATE = 2001;

// Waypoint scanning
float SENSOR_RANGE = 50.0;
float SENSOR_REPEAT = 5.0;

// Navigation
float CHARACTER_SPEED = 0.5;
integer NAVIGATION_TIMEOUT = 60; // seconds

// Shift times (from config)
string SHIFT_START_TIME = "09:00";
string SHIFT_END_TIME = "17:00";
string DAILY_REPORT_TIME = "17:05";

// Notecard reading
key notecardQuery;
integer notecardLine = 0;
string notecardName = "RoseConfig";

// ============================================================================
// STATE VARIABLES
// ============================================================================

list waypoints = []; // List of [prim_key, number, name, position]
integer current_waypoint_index = -1;
string current_state = "IDLE";
string current_activity_name = "idle";
string current_activity_id = "";

key current_target_key = NULL_KEY;
vector current_target_pos = ZERO_VECTOR;
integer navigation_start_time = 0;

integer is_navigating = FALSE;
integer wander_enabled = TRUE;
integer is_in_shift = FALSE;
integer last_report_day = -1; // Track last day report was generated

// Activity data
string activity_type = "";
string activity_animation = "";
integer activity_orientation = -1;
list activity_attachments = [];
integer activity_duration = 0;
integer activity_start_time = 0;

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Parse JSON from prim description
list parseWaypointJSON(string json)
{
    // Simple JSON parser for LSL
    // Expected format: {"type":"linger","name":"watering plants","orientation":180,"time":45,"animation":"watering","attachments":[{"item":"Can","point":"RightHand"}]}
    
    list result = [];
    
    // Extract type
    integer typeStart = llSubStringIndex(json, "\"type\":\"") + 8;
    if (typeStart > 7)
    {
        integer typeEnd = llSubStringIndex(llGetSubString(json, typeStart, -1), "\"");
        string type = llGetSubString(json, typeStart, typeStart + typeEnd - 1);
        result += [type];
    }
    else
    {
        result += ["transient"];
    }
    
    // Extract name
    integer nameStart = llSubStringIndex(json, "\"name\":\"") + 8;
    if (nameStart > 7)
    {
        integer nameEnd = llSubStringIndex(llGetSubString(json, nameStart, -1), "\"");
        string name = llGetSubString(json, nameStart, nameStart + nameEnd - 1);
        result += [name];
    }
    else
    {
        result += ["waypoint"];
    }
    
    // Extract orientation (optional)
    integer orientStart = llSubStringIndex(json, "\"orientation\":") + 15;
    if (orientStart > 14)
    {
        string orientStr = llGetSubString(json, orientStart, orientStart + 10);
        integer commaPos = llSubStringIndex(orientStr, ",");
        integer bracePos = llSubStringIndex(orientStr, "}");
        integer endPos = commaPos;
        if (endPos == -1 || (bracePos != -1 && bracePos < endPos))
            endPos = bracePos;
        
        if (endPos != -1)
        {
            orientStr = llGetSubString(orientStr, 0, endPos - 1);
            result += [(integer)orientStr];
        }
        else
        {
            result += [-1];
        }
    }
    else
    {
        result += [-1];
    }
    
    // Extract time (optional)
    integer timeStart = llSubStringIndex(json, "\"time\":") + 7;
    if (timeStart > 6)
    {
        string timeStr = llGetSubString(json, timeStart, timeStart + 10);
        integer commaPos = llSubStringIndex(timeStr, ",");
        integer bracePos = llSubStringIndex(timeStr, "}");
        integer endPos = commaPos;
        if (endPos == -1 || (bracePos != -1 && bracePos < endPos))
            endPos = bracePos;
        
        if (endPos != -1)
        {
            timeStr = llGetSubString(timeStr, 0, endPos - 1);
            result += [(integer)timeStr];
        }
        else
        {
            result += [0];
        }
    }
    else
    {
        result += [0];
    }
    
    // Extract animation (optional)
    integer animStart = llSubStringIndex(json, "\"animation\":\"") + 13;
    if (animStart > 12)
    {
        integer animEnd = llSubStringIndex(llGetSubString(json, animStart, -1), "\"");
        string anim = llGetSubString(json, animStart, animStart + animEnd - 1);
        result += [anim];
    }
    else
    {
        result += [""];
    }
    
    // Extract attachments (simplified - just store the JSON string)
    integer attachStart = llSubStringIndex(json, "\"attachments\":");
    if (attachStart != -1)
    {
        integer arrayStart = llSubStringIndex(llGetSubString(json, attachStart, -1), "[");
        if (arrayStart != -1)
        {
            arrayStart += attachStart;
            integer arrayEnd = llSubStringIndex(llGetSubString(json, arrayStart, -1), "]");
            if (arrayEnd != -1)
            {
                string attachJson = llGetSubString(json, arrayStart, arrayStart + arrayEnd);
                result += [attachJson];
            }
            else
            {
                result += [""];
            }
        }
        else
        {
            result += [""];
        }
    }
    else
    {
        result += [""];
    }
    
    return result;
}

// Extract number from waypoint name (e.g., <prefix>0, <prefix>1, etc.)
// Uses the configurable WAYPOINT_PREFIX
integer extractWaypointNumber(string name)
{
    integer prefixPos = llSubStringIndex(name, WAYPOINT_PREFIX);
    if (prefixPos != -1)
    {
        string numStr = llGetSubString(name, prefixPos + llStringLength(WAYPOINT_PREFIX), -1);
        return (integer)numStr;
    }
    return -1;
}

// Sort waypoints by number (bubble sort - simple for small lists)
list sortWaypoints(list wp)
{
    integer i;
    integer j;
    integer n = llGetListLength(wp) / 4; // Each waypoint: [key, number, name, position] = 4 elements per waypoint
    
    for (i = 0; i < n - 1; i++)
    {
        for (j = 0; j < n - i - 1; j++)
        {
            integer num1 = llList2Integer(wp, j * 4 + 1);
            integer num2 = llList2Integer(wp, (j + 1) * 4 + 1);
            
            if (num1 > num2)
            {
                // Swap waypoints
                key key1 = llList2Key(wp, j * 4);
                string name1 = llList2String(wp, j * 4 + 2);
                vector pos1 = llList2Vector(wp, j * 4 + 3);
                
                key key2 = llList2Key(wp, (j + 1) * 4);
                string name2 = llList2String(wp, (j + 1) * 4 + 2);
                vector pos2 = llList2Vector(wp, (j + 1) * 4 + 3);
                
                wp = llListReplaceList(wp, [key2, num2, name2, pos2], j * 4, j * 4 + 3);
                wp = llListReplaceList(wp, [key1, num1, name1, pos1], (j + 1) * 4, (j + 1) * 4 + 3);
            }
        }
    }
    
    return wp;
}

// HTTP request to log activity
logActivity(string activityName, string activityType, string location, integer orientation, string animation, string attachments)
{
    string json = "{\"activityName\":\"" + activityName + "\",\"activityType\":\"" + activityType + "\"";
    
    if (location != "")
        json += ",\"location\":\"" + location + "\"";
    
    if (orientation != -1)
        json += ",\"orientation\":" + (string)orientation;
    
    if (animation != "")
        json += ",\"animation\":\"" + animation + "\"";
    
    if (attachments != "")
        json += ",\"attachments\":\"" + llEscapeURL(attachments) + "\"";
    
    json += "}";
    
    list headers = [
        "Content-Type", "application/json",
        "X-API-Key", API_KEY
    ];
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities",
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"] + headers,
        json
    );
    
    llOwnerSay("Activity logged: " + activityName);
}

// HTTP request to complete activity
completeActivity(string activityId)
{
    if (activityId == "") return;
    
    list headers = [
        "Content-Type", "application/json",
        "X-API-Key", API_KEY
    ];
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/" + activityId + "/complete",
        [HTTP_METHOD, "PUT", HTTP_MIMETYPE, "application/json"] + headers,
        "{}"
    );
}

// HTTP request to get current activity (for "what are you doing?" responses)
getCurrentActivity()
{
    list headers = [
        "X-API-Key", API_KEY
    ];
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/current",
        [HTTP_METHOD, "GET"] + headers,
        ""
    );
}

// Generate end-of-shift report
generateDailyReport()
{
    string today = llGetDate();
    
    // Get shift times (simplified - using current day with configured times)
    string json = "{\"reportDate\":\"" + today + "T00:00:00Z\",\"shiftStart\":\"" + today + "T" + SHIFT_START_TIME + ":00Z\",\"shiftEnd\":\"" + today + "T" + SHIFT_END_TIME + ":00Z\"}";
    
    list headers = [
        "Content-Type", "application/json",
        "X-API-Key", API_KEY
    ];
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/daily",
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"] + headers,
        json
    );
    
    llOwnerSay("Daily report generated for " + today);
}

// ============================================================================
// NAVIGATION FUNCTIONS
// ============================================================================

createPathfindingCharacter()
{
    llCreateCharacter([
        CHARACTER_TYPE, CHARACTER_TYPE_A,
        CHARACTER_MAX_SPEED, 2.0,
        CHARACTER_DESIRED_SPEED, 1.5,
        CHARACTER_RADIUS, 0.5,
        CHARACTER_LENGTH, 1.0
    ]);
    llOwnerSay("✅ Pathfinding character created");
}

startWaypointScan()
{
    llOwnerSay("Scanning for waypoints...");
    llSensor("", NULL_KEY, PASSIVE | ACTIVE, SENSOR_RANGE, PI);
}

initializeNavigation()
{
    createPathfindingCharacter();
    llOwnerSay("Scanning for " + WAYPOINT_PREFIX + "[0-9]+ prims...");
    startWaypointScan();
}

processWaypoint(key wpKey, vector wpPos)
{
    // Get waypoint description
    list details = llGetObjectDetails(wpKey, [OBJECT_NAME, OBJECT_DESC]);
    string wpName = llList2String(details, 0);
    string wpDesc = llList2String(details, 1);
    
    // Parse JSON from description
    list wpData = parseWaypointJSON(wpDesc);
    
    activity_type = llList2String(wpData, 0);
    current_activity_name = llList2String(wpData, 1);
    activity_orientation = llList2Integer(wpData, 2);
    activity_duration = llList2Integer(wpData, 3);
    activity_animation = llList2String(wpData, 4);
    string attachments_json = llList2String(wpData, 5);
    
    llOwnerSay("Waypoint: " + wpName + " - " + current_activity_name + " (" + activity_type + ")");
    
    // Log activity start
    logActivity(current_activity_name, activity_type, wpName, activity_orientation, activity_animation, attachments_json);
    activity_start_time = llGetUnixTime();
    
    // Handle different action types
    if (activity_type == "transient")
    {
        // Pass through without stopping
        llOwnerSay("Passing through " + wpName);
        llSleep(1.0);
        moveToNextWaypoint();
    }
    else if (activity_type == "linger")
    {
        // Stop and perform actions
        llOwnerSay("Lingering at " + wpName + " for " + (string)activity_duration + " seconds");
        
        // Face direction if specified
        if (activity_orientation != -1)
        {
            float radians = activity_orientation * DEG_TO_RAD;
            rotation rot = llEuler2Rot(<0, 0, radians>);
            llSetRot(rot);
        }
        
        // Play animation if specified
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
        }
        
        // Handle attachments (simplified - notify other scripts)
        if (attachments_json != "")
        {
            llMessageLinked(LINK_SET, 0, "ATTACHMENTS:" + attachments_json, NULL_KEY);
        }
        
        // Wait for duration
        llSetTimerEvent((float)activity_duration);
        current_state = "LINGERING";
    }
    else if (activity_type == "sit")
    {
        // Find matching sit prim and sit
        // NOTE: For sitting to work properly, the waypoint prim itself should have a sit target configured.
        // This script cannot set sit targets on other objects, only the object it's in.
        // The avatar must use llSitOnObject() or the user must manually click to sit.
        llOwnerSay("Sit action at " + wpName + " - Please ensure waypoint has sit target configured");
        
        // Notify to play sit animation
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
        }
        
        current_state = "SITTING";
        
        if (activity_duration > 0)
        {
            llSetTimerEvent((float)activity_duration);
        }
    }
}

moveToNextWaypoint()
{
    // Complete previous activity if any
    if (current_activity_id != "")
    {
        completeActivity(current_activity_id);
        current_activity_id = "";
    }
    
    integer num_waypoints = llGetListLength(waypoints) / 4;
    
    if (num_waypoints == 0)
    {
        llOwnerSay("No waypoints found. Scanning again...");
        llSetTimerEvent(10.0);
        return;
    }
    
    // Move to next waypoint
    current_waypoint_index++;
    
    if (current_waypoint_index >= num_waypoints)
    {
        // Completed all waypoints, loop back to start
        current_waypoint_index = 0;
        llOwnerSay("Completed route. Starting over...");
    }
    
    current_target_key = llList2Key(waypoints, current_waypoint_index * 4);
    integer waypoint_num = llList2Integer(waypoints, current_waypoint_index * 4 + 1);
    string waypoint_name = llList2String(waypoints, current_waypoint_index * 4 + 2);
    current_target_pos = llList2Vector(waypoints, current_waypoint_index * 4 + 3);
    
    llOwnerSay("Moving to " + waypoint_name + " (" + WAYPOINT_PREFIX + (string)waypoint_num + ")");
    
    // Start navigation
    list options = [
        FORCE_DIRECT_PATH, FALSE,
        CHARACTER_TYPE, CHARACTER_TYPE_A,
        CHARACTER_MAX_SPEED, CHARACTER_SPEED
    ];
    
    llNavigateTo(current_target_pos, options);
    is_navigating = TRUE;
    navigation_start_time = llGetUnixTime();
    current_state = "WALKING";
    
    // Set timeout for navigation
    llSetTimerEvent(1.0);
}

// ============================================================================
// MAIN STATE MACHINE
// ============================================================================

default
{
    state_entry()
    {
        llOwnerSay("Rose Prim-Based Navigation System active");
        
        // Read configuration from notecard
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD)
        {
            llOwnerSay("Reading configuration from " + notecardName + "...");
            notecardLine = 0;
            notecardQuery = llGetNotecardLine(notecardName, notecardLine);
        }
        else
        {
            llOwnerSay("No RoseConfig notecard found, using defaults");
            initializeNavigation();
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
                        
                        if (configKey == "WAYPOINT_PREFIX")
                        {
                            WAYPOINT_PREFIX = value;
                            llOwnerSay("✅ WAYPOINT_PREFIX: " + WAYPOINT_PREFIX);
                        }
                        else if (configKey == "API_ENDPOINT")
                        {
                            API_ENDPOINT = value;
                        }
                        else if (configKey == "API_KEY" || configKey == "SUBSCRIBER_KEY")
                        {
                            API_KEY = value;
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
                llOwnerSay("Configuration loaded.");
                initializeNavigation();
            }
        }
    }
    
    sensor(integer num)
    {
        waypoints = [];
        integer i;
        
        llOwnerSay("Found " + (string)num + " objects");
        
        for (i = 0; i < num; i++)
        {
            string name = llDetectedName(i);
            
            // Check if this is a waypoint with the configured prefix
            if (llSubStringIndex(name, WAYPOINT_PREFIX) == 0)
            {
                integer wpNum = extractWaypointNumber(name);
                
                if (wpNum != -1)
                {
                    key wpKey = llDetectedKey(i);
                    vector wpPos = llDetectedPos(i);
                    
                    waypoints += [wpKey, wpNum, name, wpPos];
                    llOwnerSay("Found waypoint: " + name + " (" + (string)wpNum + ")");
                }
            }
        }
        
        // Sort waypoints by number
        if (llGetListLength(waypoints) > 0)
        {
            waypoints = sortWaypoints(waypoints);
            
            integer num_wp = llGetListLength(waypoints) / 4;
            llOwnerSay("Sorted " + (string)num_wp + " waypoints");
            
            // Start navigation to first waypoint
            current_waypoint_index = -1;
            moveToNextWaypoint();
        }
        else
        {
            llOwnerSay("No " + WAYPOINT_PREFIX + " waypoints found. Will retry in 30 seconds.");
            llSetTimerEvent(30.0);
        }
    }
    
    no_sensor()
    {
        llOwnerSay("No objects detected in range. Will retry in 30 seconds.");
        llSetTimerEvent(30.0);
    }
    
    timer()
    {
        if (current_state == "WALKING")
        {
            // Check for navigation timeout
            if (llGetUnixTime() - navigation_start_time > NAVIGATION_TIMEOUT)
            {
                llOwnerSay("Navigation timeout. Moving to next waypoint.");
                llNavigateTo(llGetPos(), []); // Stop current navigation
                moveToNextWaypoint();
            }
            
            // Check if we've reached the target
            vector current_pos = llGetPos();
            float distance = llVecDist(current_pos, current_target_pos);
            
            if (distance < 1.0)
            {
                // Reached waypoint
                is_navigating = FALSE;
                processWaypoint(current_target_key, current_target_pos);
            }
        }
        else if (current_state == "LINGERING" || current_state == "SITTING")
        {
            // Duration completed
            llOwnerSay("Activity duration completed");
            
            // Stop animation
            if (activity_animation != "")
            {
                llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
            }
            
            moveToNextWaypoint();
        }
        else if (current_state == "IDLE")
        {
            // Rescan for waypoints
            startWaypointScan();
        }
        
        // Check if it's time for daily report (only once per day)
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
    
    moving_end()
    {
        // Navigation completed
        is_navigating = FALSE;
        
        if (current_state == "WALKING")
        {
            // We've arrived at the waypoint
            processWaypoint(current_target_key, current_target_pos);
        }
    }
    
    link_message(integer sender, integer num, string msg, key link_id)
    {
        if (num == LINK_WANDERING_STATE)
        {
            if (msg == "GREETING" || msg == "CHATTING")
            {
                // Stop wandering during interaction
                if (is_navigating)
                {
                    llNavigateTo(llGetPos(), []);
                    is_navigating = FALSE;
                }
                
                llSetTimerEvent(0.0);
                current_state = "INTERACTING";
            }
            else if (msg == "IDLE" || msg == "RESUME")
            {
                // Resume wandering
                current_state = "IDLE";
                llSetTimerEvent(5.0);
            }
        }
        else if (msg == "TOGGLE_WANDER")
        {
            wander_enabled = !wander_enabled;
            
            string status;
            if (wander_enabled)
            {
                status = "enabled";
            }
            else
            {
                status = "disabled";
            }
            llOwnerSay("Wandering " + status);
            
            if (!wander_enabled)
            {
                if (is_navigating)
                {
                    llNavigateTo(llGetPos(), []);
                    is_navigating = FALSE;
                }
                llSetTimerEvent(0.0);
                current_state = "IDLE";
            }
            else
            {
                startWaypointScan();
            }
        }
        else if (llSubStringIndex(msg, "WHAT_DOING") == 0)
        {
            // Respond with current activity
            string response = "I'm currently " + current_activity_name;
            if (activity_type == "linger")
                response += " at " + llList2String(waypoints, current_waypoint_index * 4 + 2);
            
            llMessageLinked(LINK_SET, LINK_ACTIVITY_UPDATE, response, NULL_KEY);
        }
    }
    
    http_response(key http_request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            // Parse response to get activity ID if this was a log activity request
            if (llSubStringIndex(body, "\"id\":\"") != -1)
            {
                integer idStart = llSubStringIndex(body, "\"id\":\"") + 6;
                integer idEnd = llSubStringIndex(llGetSubString(body, idStart, -1), "\"");
                current_activity_id = llGetSubString(body, idStart, idStart + idEnd - 1);
            }
        }
        else
        {
            llOwnerSay("HTTP Error: " + (string)status);
        }
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
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
