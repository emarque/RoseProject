// RoseReceptionist_GoWander3_Manager.lsl
// Waypoint & Activity Manager - Determines next waypoint and handles activities

// CONFIGURATION
string API_ENDPOINT = "https://rosercp.pantherplays.com/api";
string API_KEY = "your-api-key-here";

string WAYPOINT_PREFIX = "Waypoint";

// Link messages
integer LINK_NAV_GOTO = 3000;      // Manager->Navigator: Go to position
integer LINK_NAV_ARRIVED = 3001;   // Navigator->Manager: Arrived at waypoint
integer LINK_NAV_TIMEOUT = 3002;   // Navigator->Manager: Navigation timeout
integer LINK_WANDERING_STATE = 2000;
integer LINK_ACTIVITY_UPDATE = 2001;

integer STAND_ANIMATION_INTERVAL = 5;
integer MAX_ACTIVITY_DURATION = 300;
integer STAY_IN_PARCEL = TRUE;
integer DOOR_DETECTION_ENABLED = TRUE;
string DOOR_NAME_PATTERN = "door";

string SHIFT_START_TIME = "09:00";
string SHIFT_END_TIME = "17:00";
string DAILY_REPORT_TIME = "17:05";

integer HOME_WAYPOINT = -1;
integer HOME_DURATION_MINUTES = 0;

// Notecard reading
key notecardQuery;
integer notecardLine = 0;
string notecardName = "RoseConfig";

key waypointConfigQuery;
integer waypointConfigLine = 0;
string WAYPOINT_CONFIG_NOTECARD = "[WPP]WaypointConfig";
list waypoint_configs = [];

// Animation lists
list available_stand_animations = [];
list available_linger_animations = [];
string default_stand = "anim stand 1";

list available_attachables = [];
integer in_attachables_section = FALSE;

// STATE VARIABLES
integer current_waypoint_index = -1;
string current_state = "IDLE";
string current_activity_name = "idle";
string current_activity_id = "";

integer wander_enabled = TRUE;
integer is_in_shift = FALSE;
integer last_report_day = -1;

integer at_home = FALSE;
integer home_start_time = 0;
integer loop_started = FALSE;

// Stand animation variation
string current_stand_animation = "";
integer last_stand_change_time = 0;

// Activity data
string activity_type = "";
string activity_animation = "";
integer activity_orientation = -1;
integer activity_duration = 0;
integer activity_start_time = 0;

// HTTP tracking
integer last_429_time = 0;
integer error_429_count = 0;

// Activity batching
list pending_activities = [];
integer BATCH_SIZE = 5;
float BATCH_INTERVAL = 300.0;
integer last_batch_time = 0;
list tracked_activities = [];

// Constants
float DEG_TO_RAD = 0.0174532925;

// Animation scanning
scanInventoryAnimations()
{
    available_stand_animations = [];
    available_linger_animations = [];
    
    integer count = llGetInventoryNumber(INVENTORY_ANIMATION);
    integer i;
    for (i = 0; i < count; i++)
    {
        string name = llGetInventoryName(INVENTORY_ANIMATION, i);
        
        if (llSubStringIndex(name, "anim ") == 0)
        {
            string remainder = llGetSubString(name, 5, -1);
            integer spacePos = llSubStringIndex(remainder, " ");
            
            if (spacePos != -1)
            {
                string category = llGetSubString(remainder, 0, spacePos - 1);
                
                if (category == "stand")
                {
                    available_stand_animations += [name];
                }
                else if (category != "walk" && category != "sit" && category != "dance" && 
                         category != "turnleft" && category != "turnright")
                {
                    available_linger_animations += [name];
                }
            }
        }
    }
}

// Switch to random stand animation
switchStandAnimation()
{
    if (current_stand_animation != "")
    {
        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + current_stand_animation, NULL_KEY);
        current_stand_animation = "";
    }
    
    integer numAnims = llGetListLength(available_stand_animations);
    if (numAnims > 0)
    {
        integer randIndex = (integer)llFrand(numAnims);
        current_stand_animation = llList2String(available_stand_animations, randIndex);
        llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + current_stand_animation, NULL_KEY);
        last_stand_change_time = llGetUnixTime();
    }
}

stopStandAnimation()
{
    if (current_stand_animation != "")
    {
        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + current_stand_animation, NULL_KEY);
        current_stand_animation = "";
    }
}

// JSON parser for waypoint configs
list parseWaypointJSON(string json)
{
    json = llStringTrim(json, STRING_TRIM);
    
    integer justNumber = (integer)json;
    if ((string)justNumber == json && justNumber > 0)
    {
        return ["linger", "pausing", -1, justNumber, "", ""];
    }
    
    string type = "transient";
    integer typeStart = llSubStringIndex(json, "\"type\":\"");
    if (typeStart != -1)
    {
        typeStart += 8;
        integer typeEnd = llSubStringIndex(llGetSubString(json, typeStart, typeStart + 20), "\"");
        if (typeEnd != -1)
        {
            type = llGetSubString(json, typeStart, typeStart + typeEnd - 1);
        }
    }
    
    string name = "waypoint";
    integer nameStart = llSubStringIndex(json, "\"name\":\"");
    if (nameStart != -1)
    {
        nameStart += 8;
        integer nameEnd = llSubStringIndex(llGetSubString(json, nameStart, nameStart + 100), "\"");
        if (nameEnd != -1)
        {
            name = llGetSubString(json, nameStart, nameStart + nameEnd - 1);
        }
    }
    
    integer orientation = -1;
    integer orientStart = llSubStringIndex(json, "\"orientation\":");
    if (orientStart != -1)
    {
        orientStart += 15;
        string orientSubstr = llGetSubString(json, orientStart, orientStart + 10);
        integer commaPos = llSubStringIndex(orientSubstr, ",");
        integer bracePos = llSubStringIndex(orientSubstr, "}");
        integer endPos = commaPos;
        if (endPos == -1 || (bracePos != -1 && bracePos < endPos))
            endPos = bracePos;
        
        if (endPos != -1)
        {
            orientation = (integer)llGetSubString(orientSubstr, 0, endPos - 1);
        }
    }
    
    integer time = 0;
    integer timeStart = llSubStringIndex(json, "\"time\":");
    if (timeStart != -1)
    {
        timeStart += 7;
        string timeSubstr = llGetSubString(json, timeStart, timeStart + 10);
        integer commaPos = llSubStringIndex(timeSubstr, ",");
        integer bracePos = llSubStringIndex(timeSubstr, "}");
        integer endPos = commaPos;
        if (endPos == -1 || (bracePos != -1 && bracePos < endPos))
            endPos = bracePos;
        
        if (endPos != -1)
        {
            time = (integer)llGetSubString(timeSubstr, 0, endPos - 1);
        }
    }
    
    string anim = "";
    integer animStart = llSubStringIndex(json, "\"animation\":\"");
    if (animStart != -1)
    {
        animStart += 13;
        integer animEnd = llSubStringIndex(llGetSubString(json, animStart, animStart + 50), "\"");
        if (animEnd != -1)
        {
            anim = llGetSubString(json, animStart, animStart + animEnd - 1);
        }
    }
    
    string attachJson = "";
    integer attachStart = llSubStringIndex(json, "\"attachments\":");
    if (attachStart != -1)
    {
        integer arrayStart = llSubStringIndex(llGetSubString(json, attachStart, attachStart + 15), "[");
        if (arrayStart != -1)
        {
            arrayStart += attachStart;
            integer arrayEnd = llSubStringIndex(llGetSubString(json, arrayStart, arrayStart + 500), "]");
            if (arrayEnd != -1)
            {
                attachJson = llGetSubString(json, arrayStart, arrayStart + arrayEnd);
            }
        }
    }
    
    return [type, name, orientation, time, anim, attachJson];
}

toggleWander()
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
        current_state = "IDLE";
        llSetTimerEvent(0.0);
    }
    else
    {
        loadWaypointConfig();
    }
}

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

queueActivity(string name, string type, integer duration)
{
    if (!isNewActivity(name))
    {
        return;
    }
    
    tracked_activities += [name];
    pending_activities += [name, type, duration, llGetUnixTime()];
    
    if (llGetListLength(pending_activities) / 4 >= BATCH_SIZE || 
        llGetUnixTime() - last_batch_time > BATCH_INTERVAL)
    {
        sendActivityBatch();
    }
}

sendActivityBatch()
{
    if (llGetListLength(pending_activities) == 0) return;
    
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
    
    key http_request_id = llHTTPRequest(API_ENDPOINT + "/activities/batch",
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    pending_activities = [];
    tracked_activities = [];
    last_batch_time = llGetUnixTime();
}

completeActivity(string activityId)
{
    if (activityId == "") return;
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/" + activityId + "/complete",
        [HTTP_METHOD, "PUT",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY],
        "{}"
    );
}

generateDailyReport()
{
    string today = llGetDate();
    
    string json = "{\"reportDate\":\"" + today + "T00:00:00Z\",\"shiftStart\":\"" + today + "T" + SHIFT_START_TIME + ":00Z\",\"shiftEnd\":\"" + today + "T" + SHIFT_END_TIME + ":00Z\"}";
    
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/daily",
        [HTTP_METHOD, "POST",
         HTTP_MIMETYPE, "application/json",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY],
        json
    );
    
    llOwnerSay("Daily report: " + today);
}

loadWaypointConfig()
{
    if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) == INVENTORY_NOTECARD)
    {
        llOwnerSay("Loading wp config: " + WAYPOINT_CONFIG_NOTECARD);
        waypointConfigLine = 0;
        waypoint_configs = [];
        waypointConfigQuery = llGetNotecardLine(WAYPOINT_CONFIG_NOTECARD, waypointConfigLine);
    }
    else
    {
        llOwnerSay("No wp config notecard");
    }
}

// Get waypoint entry size in list
integer getWaypointEntrySize(integer listIdx)
{
    if (listIdx + 2 < llGetListLength(waypoint_configs))
    {
        if (llGetListEntryType(waypoint_configs, listIdx + 2) == TYPE_STRING)
        {
            return 8;
        }
    }
    return 2;
}

// Count waypoints
integer getWaypointCount()
{
    integer count = 0;
    integer i = 0;
    while (i < llGetListLength(waypoint_configs))
    {
        i += getWaypointEntrySize(i);
        count++;
    }
    return count;
}

// Get waypoint config data
list getWaypointConfig(integer wpNumber)
{
    integer listIdx = 0;
    while (listIdx < llGetListLength(waypoint_configs))
    {
        integer wpNum = llList2Integer(waypoint_configs, listIdx);
        
        if (wpNum == wpNumber)
        {
            integer entrySize = getWaypointEntrySize(listIdx);
            if (entrySize == 8)
            {
                return [llList2String(waypoint_configs, listIdx + 2),
                        llList2String(waypoint_configs, listIdx + 3),
                        llList2Integer(waypoint_configs, listIdx + 4),
                        llList2Integer(waypoint_configs, listIdx + 5),
                        llList2String(waypoint_configs, listIdx + 6),
                        llList2String(waypoint_configs, listIdx + 7)];
            }
            return [];
        }
        
        listIdx += getWaypointEntrySize(listIdx);
    }
    return [];
}

integer findWaypointIndexByNumber(integer wpNumber)
{
    integer idx = 0;
    integer i = 0;
    while (i < llGetListLength(waypoint_configs))
    {
        if (llList2Integer(waypoint_configs, i) == wpNumber)
        {
            return idx;
        }
        i += getWaypointEntrySize(i);
        idx++;
    }
    return -1;
}

// Called when Navigator reports arrival
processWaypoint(vector wpPos)
{
    // Get waypoint config
    integer listIdx = 0;
    integer wpIdx = 0;
    while (wpIdx < current_waypoint_index && listIdx < llGetListLength(waypoint_configs))
    {
        listIdx += getWaypointEntrySize(listIdx);
        wpIdx++;
    }
    
    integer wpNumber = llList2Integer(waypoint_configs, listIdx);
    
    // Get configuration
    list configData = getWaypointConfig(wpNumber);
    
    string attachments_json = "";
    
    if (llGetListLength(configData) > 0)
    {
        activity_type = llList2String(configData, 0);
        current_activity_name = llList2String(configData, 1);
        activity_orientation = llList2Integer(configData, 2);
        activity_duration = llList2Integer(configData, 3);
        activity_animation = llList2String(configData, 4);
        attachments_json = llList2String(configData, 5);
    }
    else
    {
        activity_type = "transient";
        current_activity_name = "";
        activity_orientation = -1;
        activity_duration = 0;
        activity_animation = "";
        attachments_json = "";
    }
    
    if (activity_type != "transient" && current_activity_name != "")
    {
        llMessageLinked(LINK_SET, LINK_ACTIVITY_UPDATE, current_activity_name, NULL_KEY);
    }
    
    if (activity_type != "transient")
    {
        queueActivity(current_activity_name, activity_type, activity_duration);
    }
    activity_start_time = llGetUnixTime();
    
    // Handle different action types
    if (activity_type == "transient")
    {
        moveToNextWaypoint();
    }
    else if (activity_type == "linger")
    {
        llOwnerSay("Activity: " + current_activity_name + " (" + (string)activity_duration + "s)");
        
        // Face direction if specified
        if (activity_orientation != -1)
        {
            float radians = activity_orientation * DEG_TO_RAD;
            rotation rot = llEuler2Rot(<0, 0, radians>);
            llSetRot(rot);
        }
        
        // Play animation or use stand animations
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
            current_stand_animation = "";
        }
        else 
        {
            switchStandAnimation();
        }
        
        if (attachments_json != "")
        {
            llMessageLinked(LINK_SET, 0, "ATTACHMENTS:" + attachments_json, NULL_KEY);
        }
        
        float timer_interval = (float)STAND_ANIMATION_INTERVAL;
        if (activity_duration < STAND_ANIMATION_INTERVAL)
        {
            timer_interval = (float)activity_duration;
        }
        llSetTimerEvent(timer_interval);
        current_state = "LINGERING";
    }
    else if (activity_type == "sit")
    {
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
    if (current_activity_id != "")
    {
        completeActivity(current_activity_id);
        current_activity_id = "";
    }
    
    integer num_waypoints = getWaypointCount();
    if (num_waypoints == 0)
    {
        llOwnerSay("No wp configs");
        llSetTimerEvent(30.0);
        return;
    }
    
    // Home position logic
    if (HOME_WAYPOINT >= 0 && !loop_started)
    {
        integer home_index = findWaypointIndexByNumber(HOME_WAYPOINT);
        if (home_index == -1)
        {
            llOwnerSay("Home wp " + (string)HOME_WAYPOINT + " not found");
        }
        else
        {
            current_waypoint_index = home_index;
            at_home = TRUE;
            home_start_time = llGetUnixTime();
            loop_started = FALSE;
            
            navigateToCurrentWaypoint();
            return;
        }
    }
    
    // Check if at home
    if (at_home && HOME_DURATION_MINUTES > 0)
    {
        integer elapsed_minutes = (llGetUnixTime() - home_start_time) / 60;
        if (elapsed_minutes < HOME_DURATION_MINUTES)
        {
            llSetTimerEvent(60.0);
            return;
        }
        else
        {
            at_home = FALSE;
            loop_started = TRUE;
        }
    }
    
    // Find next non-blocked waypoint
    integer attempts = 0;
    integer found_index = -1;
    
    while (attempts < num_waypoints && found_index == -1)
    {
        current_waypoint_index = (current_waypoint_index + 1) % num_waypoints;
        
        // Check if blocked by door
        if (DOOR_DETECTION_ENABLED)
        {
            // Simplified - assume not blocked
            found_index = current_waypoint_index;
        }
        else
        {
            found_index = current_waypoint_index;
        }
        
        attempts++;
    }
    
    if (found_index == -1)
    {
        llOwnerSay("All wp blocked");
        llSetTimerEvent(30.0);
        return;
    }
    
    current_waypoint_index = found_index;
    
    navigateToCurrentWaypoint();
}

navigateToCurrentWaypoint()
{
    // Get waypoint position
    integer listIdx = 0;
    integer wpIdx = 0;
    while (wpIdx < current_waypoint_index && listIdx < llGetListLength(waypoint_configs))
    {
        listIdx += getWaypointEntrySize(listIdx);
        wpIdx++;
    }
    
    integer wpNumber = llList2Integer(waypoint_configs, listIdx);
    vector target_pos = llList2Vector(waypoint_configs, listIdx + 1);
    
    // Check parcel boundary
    if (STAY_IN_PARCEL)
    {
        list parcel_details = llGetParcelDetails(target_pos, [PARCEL_DETAILS_OWNER]);
        list current_parcel = llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_OWNER]);
        
        if (llList2Key(parcel_details, 0) != llList2Key(current_parcel, 0))
        {
            current_waypoint_index = (current_waypoint_index + 1) % getWaypointCount();
            moveToNextWaypoint();
            return;
        }
    }
    
    // Tell Navigator to go to this position
    current_state = "WALKING";
    llMessageLinked(LINK_SET, LINK_NAV_GOTO, (string)target_pos, (key)((string)wpNumber));
}

// MAIN STATE
default
{
    state_entry()
    {
        llOwnerSay("Manager ready");
        
        last_batch_time = llGetUnixTime();
        
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD)
        {
            llOwnerSay("Reading config...");
            notecardLine = 0;
            notecardQuery = llGetNotecardLine(notecardName, notecardLine);
        }
        else
        {
            llOwnerSay("No config, using defaults");
            scanInventoryAnimations();
            loadWaypointConfig();
        }
    }
    
    timer()
    {
        if (current_state == "LINGERING" || current_state == "SITTING")
        {
            integer elapsed = llGetUnixTime() - activity_start_time;
            
            if (elapsed >= MAX_ACTIVITY_DURATION)
            {
                llOwnerSay("Activity timeout: " + current_activity_name);
                if (activity_animation != "")
                {
                    llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
                }
                else
                {
                    stopStandAnimation();
                }
                moveToNextWaypoint();
            }
            else if (elapsed >= activity_duration)
            {
                llOwnerSay("Activity done: " + current_activity_name);
                
                if (activity_animation != "")
                {
                    llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
                }
                else
                {
                    stopStandAnimation();
                }
                
                moveToNextWaypoint();
            }
            else if (current_state == "LINGERING" && activity_animation == "" && STAND_ANIMATION_INTERVAL > 0)
            {
                if (current_stand_animation != "")
                {
                    integer time_since_change = llGetUnixTime() - last_stand_change_time;
                    if (time_since_change >= STAND_ANIMATION_INTERVAL)
                    {
                        switchStandAnimation();
                    }
                }
                
                integer time_until_duration = activity_duration - elapsed;
                float timer_interval = (float)STAND_ANIMATION_INTERVAL;
                if (time_until_duration < STAND_ANIMATION_INTERVAL)
                {
                    timer_interval = (float)time_until_duration;
                }
                llSetTimerEvent(timer_interval);
            }
            else
            {
                // Fallback
                integer time_until_duration = activity_duration - elapsed;
                float timer_interval = 5.0;
                if (time_until_duration < 5)
                {
                    timer_interval = (float)time_until_duration;
                }
                if (timer_interval > 0.0)
                {
                    llSetTimerEvent(timer_interval);
                }
            }
        }
        
        // Daily report check
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
        if (num == LINK_NAV_ARRIVED)
        {
            // Navigator says we arrived at waypoint
            vector pos = (vector)msg;
            processWaypoint(pos);
        }
        else if (num == LINK_NAV_TIMEOUT)
        {
            // Navigation timeout - try next waypoint
            moveToNextWaypoint();
        }
        else if (num == LINK_WANDERING_STATE)
        {
            if (msg == "GREETING" || msg == "CHATTING")
            {
                current_state = "INTERACTING";
                llSetTimerEvent(0.0);
            }
            else if (msg == "DONE")
            {
                current_state = "IDLE";
                moveToNextWaypoint();
            }
        }
        else if (msg == "TOGGLE_WANDER")
        {
            toggleWander();
        }
    }
    
    dataserver(key query_id, string data)
    {
        if (query_id == notecardQuery)
        {
            if (data != EOF)
            {
                data = llStringTrim(data, STRING_TRIM);
                
                if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    if (data == "[AvailableAttachables]")
                    {
                        in_attachables_section = TRUE;
                    }
                    else if (llGetSubString(data, 0, 0) == "[")
                    {
                        in_attachables_section = FALSE;
                    }
                    else if (in_attachables_section)
                    {
                        available_attachables += [data];
                    }
                    else
                    {
                        integer equals = llSubStringIndex(data, "=");
                        if (equals != -1)
                        {
                            string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                            string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                            
                            if (configKey == "WAYPOINT_PREFIX")
                            {
                                WAYPOINT_PREFIX = value;
                            }
                            else if (configKey == "API_ENDPOINT")
                            {
                                API_ENDPOINT = value;
                            }
                            else if (configKey == "API_KEY" || configKey == "SUBSCRIBER_KEY")
                            {
                                API_KEY = value;
                            }
                            else if (configKey == "STAND_ANIMATION_INTERVAL")
                            {
                                STAND_ANIMATION_INTERVAL = (integer)value;
                            }
                            else if (configKey == "STAY_IN_PARCEL")
                            {
                                if (llToUpper(value) == "TRUE" || value == "1")
                                {
                                    STAY_IN_PARCEL = TRUE;
                                }
                                else
                                {
                                    STAY_IN_PARCEL = FALSE;
                                }
                            }
                            else if (configKey == "HOME_WAYPOINT")
                            {
                                HOME_WAYPOINT = (integer)value;
                            }
                            else if (configKey == "HOME_DURATION_MINUTES")
                            {
                                HOME_DURATION_MINUTES = (integer)value;
                            }
                        }
                    }
                }
                
                ++notecardLine;
                notecardQuery = llGetNotecardLine(notecardName, notecardLine);
            }
            else
            {
                llOwnerSay("Config loaded");
                if (llGetListLength(available_attachables) > 0)
                {
                    llOwnerSay((string)llGetListLength(available_attachables) + " attachables");
                }
                
                scanInventoryAnimations();
                loadWaypointConfig();
                
                if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) != INVENTORY_NOTECARD)
                {
                    moveToNextWaypoint();
                }
            }
        }
        else if (query_id == waypointConfigQuery)
        {
            if (data != EOF)
            {
                data = llStringTrim(data, STRING_TRIM);
                
                if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    integer equals = llSubStringIndex(data, "=");
                    if (equals != -1)
                    {
                        string key = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                        
                        if (llSubStringIndex(key, WAYPOINT_PREFIX) == 0)
                        {
                            integer wpNum = (integer)llGetSubString(key, llStringLength(WAYPOINT_PREFIX), -1);
                            
                            integer pipePos = llSubStringIndex(value, "|");
                            if (pipePos != -1)
                            {
                                string posStr = llGetSubString(value, 0, pipePos - 1);
                                string jsonStr = llGetSubString(value, pipePos + 1, -1);
                                vector pos = (vector)posStr;
                                
                                list wpData = parseWaypointJSON(jsonStr);
                                string wpType = llList2String(wpData, 0);
                                
                                if (wpType == "transient")
                                {
                                    waypoint_configs += [wpNum, pos];
                                }
                                else
                                {
                                    waypoint_configs += [wpNum, pos] + wpData;
                                }
                            }
                            else
                            {
                                vector pos = (vector)value;
                                waypoint_configs += [wpNum, pos];
                            }
                        }
                    }
                }
                
                ++waypointConfigLine;
                waypointConfigQuery = llGetNotecardLine(WAYPOINT_CONFIG_NOTECARD, waypointConfigLine);
            }
            else
            {
                integer configCount = getWaypointCount();
                llOwnerSay((string)configCount + " waypoints");
                moveToNextWaypoint();
            }
        }
    }
    
    http_response(key http_request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            // Success
        }
        else if (status == 429)
        {
            // Rate limit
            integer now = llGetUnixTime();
            if (now - last_429_time > 300)
            {
                if (error_429_count > 1)
                {
                    llOwnerSay("429 x" + (string)error_429_count);
                }
                else
                {
                    llOwnerSay("429 throttled");
                }
                last_429_time = now;
                error_429_count = 0;
            }
        }
        else
        {
            llOwnerSay("HTTP " + (string)status);
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD)
            {
                llResetScript();
            }
            else if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) == INVENTORY_NOTECARD)
            {
                llResetScript();
            }
            else
            {
                scanInventoryAnimations();
            }
        }
    }
}
