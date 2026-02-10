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

// Waypoint config notecard reading
key waypointConfigQuery;
integer waypointConfigLine = 0;
string WAYPOINT_CONFIG_NOTECARD = "[WPP]WaypointConfig";
list waypoint_configs = []; // [wp_num, wp_pos, json_config, ...]

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
    
    json = llStringTrim(json, STRING_TRIM);
    
    // Check if it's just a number (simple mode)
    integer justNumber = (integer)json;
    if ((string)justNumber == json && justNumber > 0)
    {
        return ["linger", "pausing", -1, justNumber, "", ""];
    }
    
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
list sortWaypointsByNumber(list wp)
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
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities",
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY],
        json
    );
}

// HTTP request to complete activity
completeActivity(string activityId)
{
    if (activityId == "") return;
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/" + activityId + "/complete",
        [HTTP_METHOD, "PUT",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY],
        "{}"
    );
}

// HTTP request to get current activity (for "what are you doing?" responses)
getCurrentActivity()
{
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/current",
        [HTTP_METHOD, "GET",
         HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY],
        ""
    );
}

// Generate end-of-shift report
generateDailyReport()
{
    string today = llGetDate();
    
    // Get shift times (simplified - using current day with configured times)
    string json = "{\"reportDate\":\"" + today + "T00:00:00Z\",\"shiftStart\":\"" + today + "T" + SHIFT_START_TIME + ":00Z\",\"shiftEnd\":\"" + today + "T" + SHIFT_END_TIME + ":00Z\"}";
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/daily",
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", API_KEY],
        json
    );
    
    llOwnerSay("Daily report generated for " + today);
}

// Load waypoint configurations from notecard
loadWaypointConfig()
{
    if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) == INVENTORY_NOTECARD)
    {
        waypoint_configs = [];
        waypointConfigLine = 0;
        waypointConfigQuery = llGetNotecardLine(WAYPOINT_CONFIG_NOTECARD, waypointConfigLine);
        llOwnerSay("📖 Loading waypoint configurations from " + WAYPOINT_CONFIG_NOTECARD + "...");
    }
    else
    {
        llOwnerSay("⚠️ No " + WAYPOINT_CONFIG_NOTECARD + " found. Using prim descriptions (legacy mode).");
        waypoint_configs = [];
    }
}

// Get waypoint position by waypoint number
vector getWaypointPosition(integer waypoint_number)
{
    integer i;
    for (i = 0; i < llGetListLength(waypoint_configs); i += 3)
    {
        if (llList2Integer(waypoint_configs, i) == waypoint_number)
        {
            return llList2Vector(waypoint_configs, i + 1);
        }
    }
    return ZERO_VECTOR;
}

// Get waypoint configuration by waypoint number
string getWaypointConfig(integer waypoint_number)
{
    integer i;
    for (i = 0; i < llGetListLength(waypoint_configs); i += 3)
    {
        if (llList2Integer(waypoint_configs, i) == waypoint_number)
        {
            return llList2String(waypoint_configs, i + 2);
        }
    }
    return "";
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
        CHARACTER_DESIRED_TURN_SPEED, 1.8,
        CHARACTER_RADIUS, 0.5,
        CHARACTER_LENGTH, 1.0,
        CHARACTER_AVOIDANCE_MODE, AVOID_CHARACTERS | AVOID_DYNAMIC_OBSTACLES
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
    // Get waypoint details
    list details = llGetObjectDetails(wpKey, [OBJECT_NAME, OBJECT_DESC]);
    string wpName = llList2String(details, 0);
    string wpDesc = llList2String(details, 1);
    
    // Extract waypoint number from name
    integer wpNumber = extractWaypointNumber(wpName);
    
    // Try to get configuration from notecard first
    string configJson = getWaypointConfig(wpNumber);
    
    // Fall back to prim description if no notecard config
    if (configJson == "")
    {
        configJson = wpDesc;
    }
    
    // Parse JSON configuration
    list wpData = parseWaypointJSON(configJson);
    
    activity_type = llList2String(wpData, 0);
    current_activity_name = llList2String(wpData, 1);
    activity_orientation = llList2Integer(wpData, 2);
    activity_duration = llList2Integer(wpData, 3);
    activity_animation = llList2String(wpData, 4);
    string attachments_json = llList2String(wpData, 5);
    
    // Log activity start
    logActivity(current_activity_name, activity_type, wpName, activity_orientation, activity_animation, attachments_json);
    activity_start_time = llGetUnixTime();
    
    // Handle different action types
    if (activity_type == "transient")
    {
        // Pass through without stopping
        llSleep(1.0);
        moveToNextWaypoint();
    }
    else if (activity_type == "linger")
    {
        // Stop and perform actions
        
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
    
    integer num_waypoints = llGetListLength(waypoint_configs) / 3;
    if (num_waypoints == 0)
    {
        llSetTimerEvent(30.0);
        return;
    }
    
    current_waypoint_index++;
    if (current_waypoint_index >= num_waypoints)
    {
        current_waypoint_index = 0;
    }
    
    integer wpNumber = llList2Integer(waypoint_configs, current_waypoint_index * 3);
    current_target_pos = llList2Vector(waypoint_configs, current_waypoint_index * 3 + 1);
    
    llSay(0, "→ Waypoint " + (string)wpNumber);
    
    llNavigateTo(current_target_pos, []);
    is_navigating = TRUE;
    navigation_start_time = llGetUnixTime();
    current_state = "WALKING";
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
                // Finished reading RoseConfig, now load waypoint config
                llOwnerSay("Configuration loaded.");
                loadWaypointConfig();
                
                // If no waypoint config notecard, start navigation
                if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) != INVENTORY_NOTECARD)
                {
                    initializeNavigation();
                }
            }
        }
        else if (query_id == waypointConfigQuery)
        {
            if (data != EOF)
            {
                // Process waypoint config line
                data = llStringTrim(data, STRING_TRIM);
                
                // Skip empty lines and comments
                if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    // Parse WAYPOINT<number>=<JSON>
                    integer equals = llSubStringIndex(data, "=");
                    if (equals != -1)
                    {
                        string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                        
                        // Check if key starts with "WAYPOINT"
                        if (llSubStringIndex(configKey, "WAYPOINT") == 0)
                        {
                            // Extract waypoint number
                            string numStr = llGetSubString(configKey, 8, -1);
                            integer wpNum = (integer)numStr;
                            
                            // Parse position and JSON: <x,y,z>|{json}
                            integer pipePos = llSubStringIndex(value, "|");
                            if (pipePos != -1)
                            {
                                string posStr = llGetSubString(value, 0, pipePos - 1);
                                string jsonStr = llGetSubString(value, pipePos + 1, -1);
                                vector pos = (vector)posStr;
                                waypoint_configs += [wpNum, pos, jsonStr];
                            }
                        }
                    }
                }
                
                // Read next line
                ++waypointConfigLine;
                waypointConfigQuery = llGetNotecardLine(WAYPOINT_CONFIG_NOTECARD, waypointConfigLine);
            }
            else
            {
                // Finished reading waypoint config
                integer configCount = llGetListLength(waypoint_configs) / 3;
                llOwnerSay("✅ Loaded " + (string)configCount + " waypoint configurations");
                initializeNavigation();
            }
        }
    }
    
    sensor(integer num_detected)
    {
        waypoints = [];
        integer i;
        for (i = 0; i < num_detected; i++)
        {
            string primName = llDetectedName(i);
            string primNameLower = llToLower(primName);
            string prefixLower = llToLower(WAYPOINT_PREFIX);
            
            // Case-insensitive prefix check
            if (llSubStringIndex(primNameLower, prefixLower) == 0)
            {
                // Extract remainder after prefix
                string remainder = llGetSubString(primName, llStringLength(WAYPOINT_PREFIX), -1);
                
                // Trim spaces: "Waypoint 1" -> "1"
                remainder = llStringTrim(remainder, STRING_TRIM_HEAD);
                
                // Parse number
                integer wpNumber = (integer)remainder;
                
                // Validate (handles "0" case)
                if (wpNumber > 0 || remainder == "0")
                {
                    key wpKey = llDetectedKey(i);
                    vector wpPos = llDetectedPos(i);
                    
                    waypoints += [wpKey, wpNumber, primName, wpPos];
                }
            }
        }
        
        waypoints = sortWaypointsByNumber(waypoints);
        
        // Start navigation to first waypoint
        if (llGetListLength(waypoints) > 0)
        {
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
            else if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) == INVENTORY_NOTECARD)
            {
                llOwnerSay("🔄 Waypoint configuration updated, reloading...");
                llResetScript();
            }
        }
    }
}
