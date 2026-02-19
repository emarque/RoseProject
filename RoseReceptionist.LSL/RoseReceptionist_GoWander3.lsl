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

// Navigation - Using keyframed motion instead of pathfinding
float MOVEMENT_SPEED = 1.5;  // meters per second
integer NAVIGATION_TIMEOUT = 60; // seconds
float WAYPOINT_POSITION_TOLERANCE = .0125; // meters
integer STAY_IN_PARCEL = TRUE;  // Prevent character from leaving parcel

// Door blocking detection
integer DOOR_DETECTION_ENABLED = TRUE;
string DOOR_NAME_PATTERN = "door";  // Case-insensitive partial match

// Shift times (from config)
string SHIFT_START_TIME = "09:00";
string SHIFT_END_TIME = "17:00";
string DAILY_REPORT_TIME = "17:05";

// Home position configuration
integer HOME_WAYPOINT = -1;  // Waypoint number to use as home (-1 = disabled)
integer HOME_DURATION_MINUTES = 0;  // Minutes to spend at home before starting activities

// Notecard reading
key notecardQuery;
integer notecardLine = 0;
string notecardName = "RoseConfig";

// Waypoint config notecard reading
key waypointConfigQuery;
integer waypointConfigLine = 0;
string WAYPOINT_CONFIG_NOTECARD = "[WPP]WaypointConfig";
// Waypoint storage format (variable length):
// Transient: [wpNum, pos] (2 elements)
// Linger/Sit: [wpNum, pos, type, name, orientation, time, animation, attachments] (8 elements)
list waypoint_configs = [];

// Animation lists discovered from inventory
list available_walk_animations = [];    // "anim walk" animations for navigation
list available_stand_animations = [];   // "anim stand" animations
list available_sit_animations = [];     // "anim sit" animations
list available_dance_animations = [];   // "anim dance" animations
list available_turnleft_animations = []; // "anim turnleft" animations
list available_turnright_animations = []; // "anim turnright" animations
list available_linger_animations = [];  // Other "anim [tag]" for linger tasks
string default_stand = "anim stand 1";

// Attachables from RoseConfig
list available_attachables = [];
integer in_attachables_section = FALSE;  // Flag for reading attachables section

// ============================================================================
// STATE VARIABLES
// ============================================================================

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

// Home position state
integer at_home = FALSE;  // Currently at home position
integer home_start_time = 0;  // When we arrived at home
integer loop_started = FALSE;  // Whether we've started the wander loop

// Walk animation state
string current_walk_animation = "";  // Currently playing walk animation

// Activity data
string activity_type = "";
string activity_animation = "";
integer activity_orientation = -1;
list activity_attachments = [];
integer activity_duration = 0;
integer activity_start_time = 0;

// HTTP error tracking (to prevent spam)
integer last_429_time = 0;
integer error_429_count = 0;

// Activity batching
list pending_activities = []; // [name, type, duration, timestamp, ...]
integer BATCH_SIZE = 5;
float BATCH_INTERVAL = 300.0; // 5 minutes
integer last_batch_time = 0;

// Track unique activities only
list tracked_activities = []; // [activity_name, ...]

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Scan inventory for animations and categorize by naming convention
scanInventoryAnimations()
{
    // Clear all animation lists
    available_walk_animations = [];
    available_stand_animations = [];
    available_sit_animations = [];
    available_dance_animations = [];
    available_turnleft_animations = [];
    available_turnright_animations = [];
    available_linger_animations = [];
    
    // Scan all animations in inventory
    integer inv_count = llGetInventoryNumber(INVENTORY_ANIMATION);
    integer i;
    
    for (i = 0; i < inv_count; i++)
    {
        string anim_name = llGetInventoryName(INVENTORY_ANIMATION, i);
        
        // Only process animations starting with "anim "
        if (llSubStringIndex(anim_name, "anim ") == 0)
        {
            // Check the specific category - must match "anim [category] " or end after category
            string after_anim = llGetSubString(anim_name, 5, -1); // Skip "anim "
            
            if (llSubStringIndex(after_anim, "walk ") == 0 || after_anim == "walk")
            {
                available_walk_animations += [anim_name];
            }
            else if (llSubStringIndex(after_anim, "stand ") == 0 || after_anim == "stand")
            {
                available_stand_animations += [anim_name];
            }
            else if (llSubStringIndex(after_anim, "sit ") == 0 || after_anim == "sit")
            {
                available_sit_animations += [anim_name];
            }
            else if (llSubStringIndex(after_anim, "dance ") == 0 || after_anim == "dance")
            {
                available_dance_animations += [anim_name];
            }
            else if (llSubStringIndex(after_anim, "turnleft ") == 0 || after_anim == "turnleft")
            {
                available_turnleft_animations += [anim_name];
            }
            else if (llSubStringIndex(after_anim, "turnright ") == 0 || after_anim == "turnright")
            {
                available_turnright_animations += [anim_name];
            }
            else
            {
                // Any other "anim [tag]" goes to linger animations
                available_linger_animations += [anim_name];
            }
        }
    }
    
    // Consolidated report
    llOwnerSay("Animations: " + (string)llGetListLength(available_walk_animations) + " walk, " + 
               (string)llGetListLength(available_linger_animations) + " linger");
}

// Start a random walk animation
startWalkAnimation()
{
    // Stop any current walk animation first
    stopWalkAnimation();
    
    // Check if we have walk animations available
    if (llGetListLength(available_walk_animations) == 0)
    {
        // No walk animations configured, skip
        return;
    }
    
    // Pick a random walk animation from the list
    integer anim_count = llGetListLength(available_walk_animations);
    integer random_index = (integer)llFrand(anim_count);
    string walk_anim = llList2String(available_walk_animations, random_index);
    
    // Check if animation exists in inventory
    if (llGetInventoryType(walk_anim) == INVENTORY_ANIMATION)
    {
        llStartObjectAnimation(walk_anim);
        current_walk_animation = walk_anim;
    }
    else
    {
        llOwnerSay("Walk anim not found: " + walk_anim);
    }
}

// Stop the current walk animation
stopWalkAnimation()
{
    if (current_walk_animation != "")
    {
        llStopObjectAnimation(current_walk_animation);
        current_walk_animation = "";
    }
}

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
    
    // Extract type - optimized to reduce temporary strings
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
    
    // Extract name
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
    
    // Extract orientation (optional)
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
            orientation = (integer)llGetSubString(json, orientStart, orientStart + endPos - 1);
        }
    }
    
    // Extract time (optional)
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
            time = (integer)llGetSubString(json, timeStart, timeStart + endPos - 1);
        }
    }
    
    // Extract animation (optional)
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
    
    // Extract attachments (simplified - just store the JSON string)
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
    
    // Return single list to avoid additional list operations
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
        if (is_navigating)
        {
            llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
            stopWalkAnimation();
            is_navigating = FALSE;
        }
        llSetTimerEvent(0.0);
        current_state = "IDLE";
    }
    else
    {
        loadWaypointConfig();
    }
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

integer isNewActivity(string activity_name)
{
    return llListFindList(tracked_activities, [activity_name]) == -1;
}

queueActivity(string name, string type, integer duration)
{
    // Only track if new unique activity
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
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY,
         HTTP_BODY_MAXLENGTH, 16384],
        json);
    
    //llOwnerSay("Sent batch: " + (string)(llGetListLength(pending_activities) / 4) + " activities");
    
    pending_activities = [];
    tracked_activities = []; // Clear to prevent unbounded memory growth - activities are unique per batch
    last_batch_time = llGetUnixTime();
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
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY],
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
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY],
        "{}"
    );
}

// HTTP request to get current activity (for "what are you doing?" responses)
getCurrentActivity()
{
    key http_request_id = llHTTPRequest(
        API_ENDPOINT + "/reports/activities/current",
        [HTTP_METHOD, "GET",
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY],
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
         HTTP_CUSTOM_HEADER, "X-API-Key", (string)API_KEY],
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
        llOwnerSay("Loading waypoint config: " + WAYPOINT_CONFIG_NOTECARD);
    }
    else
    {
        llOwnerSay("No " + WAYPOINT_CONFIG_NOTECARD + " found");
        waypoint_configs = [];
    }
}

// Helper function to get the size of a waypoint entry
integer getWaypointEntrySize(integer index)
{
    // Check if this is a transient waypoint (only 2 elements) or linger/sit (8 elements)
    if (index + 2 < llGetListLength(waypoint_configs))
    {
        string typeField = llList2String(waypoint_configs, index + 2);
        // If element at index+2 is a type string, it's a linger/sit waypoint (8 elements)
        if (typeField == "transient" || typeField == "linger" || typeField == "sit")
        {
            return 8; // [wpNum, pos, type, name, orientation, time, animation, attachments]
        }
    }
    return 2; // Transient: [wpNum, pos]
}

// Helper function to count total waypoints
integer getWaypointCount()
{
    integer count = 0;
    integer i = 0;
    while (i < llGetListLength(waypoint_configs))
    {
        count++;
        i += getWaypointEntrySize(i);
    }
    return count;
}

// Helper function to find waypoint by number and return its index in the list
integer findWaypointListIndex(integer waypoint_number)
{
    integer i = 0;
    while (i < llGetListLength(waypoint_configs))
    {
        if (llList2Integer(waypoint_configs, i) == waypoint_number)
        {
            return i;
        }
        i += getWaypointEntrySize(i);
    }
    return -1;
}

// Get waypoint position by waypoint number
vector getWaypointPosition(integer waypoint_number)
{
    integer idx = findWaypointListIndex(waypoint_number);
    if (idx != -1)
    {
        return llList2Vector(waypoint_configs, idx + 1);
    }
    return ZERO_VECTOR;
}

// Get waypoint configuration by waypoint number
// Returns parsed list: [type, name, orientation, time, animation, attachments]
// For transient waypoints, returns: ["transient", "", -1, 0, "", ""]
list getWaypointConfig(integer waypoint_number)
{
    integer idx = findWaypointListIndex(waypoint_number);
    if (idx == -1)
    {
        return [];
    }
    
    integer entrySize = getWaypointEntrySize(idx);
    if (entrySize == 2)
    {
        // Transient waypoint - return default values
        return ["transient", "", -1, 0, "", ""];
    }
    else
    {
        // Linger/sit waypoint - return parsed data
        // Extract: [type, name, orientation, time, animation, attachments]
        return llList2List(waypoint_configs, idx + 2, idx + 7);
    }
}

// Find the index of a waypoint by its number (logical index, not list index)
integer findWaypointIndexByNumber(integer waypoint_number)
{
    integer listIdx = 0;
    integer waypointIdx = 0;
    while (listIdx < llGetListLength(waypoint_configs))
    {
        if (llList2Integer(waypoint_configs, listIdx) == waypoint_number)
        {
            return waypointIdx;
        }
        listIdx += getWaypointEntrySize(listIdx);
        waypointIdx++;
    }
    return -1;  // Not found
}

// ============================================================================
// DOOR BLOCKING DETECTION
// ============================================================================

// Check if a waypoint is blocked by a closed door
integer isWaypointBlocked(vector target_pos)
{
    //if (!DOOR_DETECTION_ENABLED) return FALSE;
    return FALSE;
    vector start_pos = llGetPos();
    vector direction = target_pos - start_pos;
    float distance = llVecMag(direction);
    
    // Cast a ray from current position to target to detect obstacles
    list results = llCastRay(start_pos, target_pos, [
        RC_REJECT_TYPES, RC_REJECT_AGENTS | RC_REJECT_LAND,
        RC_MAX_HITS, 10,
        RC_DATA_FLAGS, RC_GET_ROOT_KEY | RC_GET_LINK_NUM
    ]);
    
    integer status = llList2Integer(results, -1);
    if (status < 0) return FALSE;  // Ray cast failed or no hits
    
    integer num_hits = llList2Integer(results, -1);
    if (num_hits == 0) return FALSE;  // No objects in the way
    
    // Check each detected object
    integer i;
    for (i = 0; i < num_hits; i++)
    {
        key hit_key = llList2Key(results, i * 2);
        
        // Get object name
        list obj_details = llGetObjectDetails(hit_key, [OBJECT_NAME, OBJECT_ROT]);
        string obj_name = llList2String(obj_details, 0);
        
        // Check if it matches door pattern (case-insensitive)
        if (llSubStringIndex(llToLower(obj_name), llToLower(DOOR_NAME_PATTERN)) != -1)
        {
            // It's a door in the path - consider it blocking
            return TRUE;
        }
    }
    
    return FALSE;
}

// Find next unblocked waypoint starting from current index
integer findNextUnblockedWaypoint()
{
    integer num_waypoints = getWaypointCount();
    if (num_waypoints == 0) return -1;
    
    integer start_index = current_waypoint_index;
    integer checked = 0;
    
    // Try up to all waypoints to find an unblocked one
    while (checked < num_waypoints)
    {
        current_waypoint_index++;
        if (current_waypoint_index >= num_waypoints)
        {
            current_waypoint_index = 0;
        }
        
        // Get waypoint number at this index
        integer listIdx = 0;
        integer wpIdx = 0;
        while (wpIdx < current_waypoint_index && listIdx < llGetListLength(waypoint_configs))
        {
            listIdx += getWaypointEntrySize(listIdx);
            wpIdx++;
        }
        
        if (listIdx < llGetListLength(waypoint_configs))
        {
            vector test_pos = llList2Vector(waypoint_configs, listIdx + 1);
            
            if (!isWaypointBlocked(test_pos))
            {
                // Found an unblocked waypoint
                return current_waypoint_index;
            }
        }
        
        checked++;
    }
    
    // All waypoints are blocked
    return -1;
}

// ============================================================================
// NAVIGATION FUNCTIONS
// ============================================================================

initializeNavigation()
{
    llOwnerSay("Navigation initialized with waypoint configurations from notecard");
    // Start wandering if waypoint configs are loaded
    if (llGetListLength(waypoint_configs) > 0)
    {
        current_waypoint_index = -1;
        moveToNextWaypoint();
    }
    else
    {
        llOwnerSay("No waypoint configs. Add " + WAYPOINT_CONFIG_NOTECARD);
    }
}

processWaypoint(key wpKey, vector wpPos)
{
    string wpName = "";
    string wpDesc = "";
    integer wpNumber = -1;
    
    // Get waypoint details from prim if available
    if (wpKey != NULL_KEY)
    {
        list details = llGetObjectDetails(wpKey, [OBJECT_NAME, OBJECT_DESC]);
        wpName = llList2String(details, 0);
        wpDesc = llList2String(details, 1);
        wpNumber = extractWaypointNumber(wpName);
    }
    else
    {
        // No prim key, use position to find waypoint number from configs
        integer listIdx = 0;
        while (listIdx < llGetListLength(waypoint_configs))
        {
            vector configPos = llList2Vector(waypoint_configs, listIdx + 1);
            if (llVecDist(configPos, wpPos) < WAYPOINT_POSITION_TOLERANCE)
            {
                wpNumber = llList2Integer(waypoint_configs, listIdx);
                wpName = "Waypoint" + (string)wpNumber;
                jump found;
            }
            listIdx += getWaypointEntrySize(listIdx);
        }
        @found;
    }
    
    // Try to get configuration from notecard first
    list configData = getWaypointConfig(wpNumber);
    
    // If we have parsed config data, use it directly
    if (llGetListLength(configData) > 0)
    {
        // Use pre-parsed data: [type, name, orientation, time, animation, attachments]
        activity_type = llList2String(configData, 0);
        current_activity_name = llList2String(configData, 1);
        activity_orientation = llList2Integer(configData, 2);
        activity_duration = llList2Integer(configData, 3);
        activity_animation = llList2String(configData, 4);
        string attachments_json = llList2String(configData, 5);
    }
    else if (wpDesc != "")
    {
        // Fall back to prim description if no notecard config
        list wpData = parseWaypointJSON(wpDesc);
        activity_type = llList2String(wpData, 0);
        current_activity_name = llList2String(wpData, 1);
        activity_orientation = llList2Integer(wpData, 2);
        activity_duration = llList2Integer(wpData, 3);
        activity_animation = llList2String(wpData, 4);
        string attachments_json = llList2String(wpData, 5);
    }
    else
    {
        // Default to transient with no name
        activity_type = "transient";
        current_activity_name = "";
        activity_orientation = -1;
        activity_duration = 0;
        activity_animation = "";
        string attachments_json = "";
    }
    
    // Notify Main script of current activity (only if not transient or has a name)
    if (activity_type != "transient" && current_activity_name != "")
    {
        llMessageLinked(LINK_SET, LINK_ACTIVITY_UPDATE, current_activity_name, NULL_KEY);
    }
    
    // Queue activity for batch logging (skip transient waypoints)
    if (activity_type != "transient")
    {
        queueActivity(current_activity_name, activity_type, activity_duration);
    }
    activity_start_time = llGetUnixTime();
    
    // Handle different action types
    if (activity_type == "transient")
    {
        // Pass through without stopping
        //llSleep(1.0);
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
        else 
        {
            integer numAnims = llGetListLength(available_stand_animations);
            integer randIndex = (integer)llFrand(numAnims);
            llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + llList2String(available_stand_animations, randIndex), NULL_KEY);
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
    
    integer num_waypoints = getWaypointCount();
    if (num_waypoints == 0)
    {
        llOwnerSay("No waypoint configs available");
        llSetTimerEvent(30.0);
        return;
    }
    
    // Home position logic
    if (HOME_WAYPOINT >= 0 && !loop_started)
    {
        // First time or returning to home - go to home position
        integer home_index = findWaypointIndexByNumber(HOME_WAYPOINT);
        if (home_index == -1)
        {
            llOwnerSay("Home waypoint " + (string)HOME_WAYPOINT + " not found!");
            // Continue with normal wandering
        }
        else
        {
            // Go to home position
            current_waypoint_index = home_index;
            at_home = TRUE;
            home_start_time = llGetUnixTime();
            loop_started = FALSE;  // Will stay at home first
            
            // Navigate to home, processWaypoint will handle the duration
            navigateToCurrentWaypoint();
            return;
        }
    }
    
    // Check if we should stay at home longer
    if (at_home && HOME_DURATION_MINUTES > 0)
    {
        integer elapsed_minutes = (llGetUnixTime() - home_start_time) / 60;
        if (elapsed_minutes < HOME_DURATION_MINUTES)
        {
            // Still need to stay at home
            llSetTimerEvent(60.0);  // Check again in a minute
            return;
        }
        else
        {
            // Time to start wandering
            at_home = FALSE;
            loop_started = TRUE;
        }
    }
    
    // Find next unblocked waypoint
    integer found_index = findNextUnblockedWaypoint();
    
    if (found_index == -1)
    {
        llOwnerSay("All waypoints blocked, waiting...");
        llSetTimerEvent(30.0);  // Try again in 30 seconds
        return;
    }
    
    current_waypoint_index = found_index;
    
    // Get waypoint number at current index
    integer listIdx = 0;
    integer wpIdx = 0;
    while (wpIdx < current_waypoint_index && listIdx < llGetListLength(waypoint_configs))
    {
        listIdx += getWaypointEntrySize(listIdx);
        wpIdx++;
    }
    integer wpNumber = llList2Integer(waypoint_configs, listIdx);
    
    // Check if we completed a full loop (back to waypoint 0 or home)
    if (loop_started && wpNumber == 0 && HOME_WAYPOINT >= 0)
    {
        // Completed loop, return to home
        loop_started = FALSE;
        current_waypoint_index = findWaypointIndexByNumber(HOME_WAYPOINT);
        if (current_waypoint_index == -1)
        {
            current_waypoint_index = 0;  // Fallback to waypoint 0
        }
        at_home = TRUE;
        home_start_time = llGetUnixTime();
    }
    
    navigateToCurrentWaypoint();
}

// Extracted navigation logic from moveToNextWaypoint
navigateToCurrentWaypoint()
{
    // Get waypoint position at current index
    integer listIdx = 0;
    integer wpIdx = 0;
    while (wpIdx < current_waypoint_index && listIdx < llGetListLength(waypoint_configs))
    {
        listIdx += getWaypointEntrySize(listIdx);
        wpIdx++;
    }
    
    // Use waypoint configs from notecard
    integer wpNumber = llList2Integer(waypoint_configs, listIdx);
    current_target_pos = llList2Vector(waypoint_configs, listIdx + 1);
    current_target_key = NULL_KEY; // No prim keys, using positions only
    
    // Check if target is outside parcel boundary
    if (STAY_IN_PARCEL)
    {
        list parcel_details = llGetParcelDetails(current_target_pos, [PARCEL_DETAILS_OWNER]);
        list current_parcel = llGetParcelDetails(llGetPos(), [PARCEL_DETAILS_OWNER]);
        
        if (llList2Key(parcel_details, 0) != llList2Key(current_parcel, 0))
        {
            // Target is in different parcel, skip this waypoint
            current_waypoint_index = (current_waypoint_index + 1) % getWaypointCount();
            moveToNextWaypoint();
            return;
        }
    }
    
    // Calculate movement parameters for keyframed motion
    vector start_pos = llGetPos();
    vector offset = current_target_pos - start_pos;
    float distance = llVecMag(offset);
    float time_to_travel = distance / MOVEMENT_SPEED;
    
    // Enforce minimum time for keyframed motion
    if (time_to_travel < 0.14)
    {
        time_to_travel = 0.14;
    }
    
    // Calculate rotation to face direction of travel (2-axis only, no diagonal lean)
    //vector direction = llVecNorm(offset);
    //float angle = llAtan2(direction.y, direction.x);  // Horizontal angle only
    //rotation facing = llEuler2Rot(<0, 0, angle - PI_BY_TWO>);  // Z-axis rotation only
    //llSetRot(facing);
    //vector vTarget=llList2Vector(llGetObjectDetails("targetkey",[OBJECT_POS]),0);
    //vector vPos=llGetPos(); //object position
    float fDistance=llVecDist(<current_target_pos.x,current_target_pos.y,0>,<start_pos.x,start_pos.y,0>); // XY Distance, disregarding height differences.
    llSetRot(llRotBetween(<1,0,0>,llVecNorm(<fDistance,0,current_target_pos.z - start_pos.z>)) * llRotBetween(<1,0,0>,llVecNorm(<current_target_pos.x - start_pos.x,current_target_pos.y - start_pos.y,0>)));
    
    // Start a random walk animation before navigating
    startWalkAnimation();
    
    // Use keyframed motion to move to waypoint
    // Stop any existing motion first
    llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
    
    // Set up the motion - for KFM_TRANSLATION mode: [position_vector, time, ...]
    llSetKeyframedMotion([offset, time_to_travel], 
                         [KFM_MODE, KFM_FORWARD, KFM_DATA, KFM_TRANSLATION]);
    
    // Start the motion
    llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_PLAY]);
    
    is_navigating = TRUE;
    navigation_start_time = llGetUnixTime();
    current_state = "WALKING";
    llSetTimerEvent(1.0);  // Check progress every second
}

// ============================================================================
// MAIN STATE MACHINE
// ============================================================================

default
{
    state_entry()
    {
        llOwnerSay("Rose Prim-Based Navigation System active");
        
        // Enable physics for keyframed motion
        llSetStatus(STATUS_PHYSICS, FALSE);
        
        // Initialize batch timing
        last_batch_time = llGetUnixTime();
        
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
            // Still scan inventory for animations
            scanInventoryAnimations();
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
                
                // Check for section headers
                if (data == "[AvailableAttachables]")
                {
                    in_attachables_section = TRUE;
                }
                // Skip empty lines and comments
                else if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    // If we're in attachables section, add to list
                    if (in_attachables_section && llSubStringIndex(data, "=") == -1)
                    {
                        available_attachables += [data];
                    }
                    else
                    {
                        // Parse KEY=VALUE (resets section flag)
                        integer equals = llSubStringIndex(data, "=");
                        if (equals != -1)
                        {
                            in_attachables_section = FALSE;
                            string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                            string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                            
                            if (configKey == "WAYPOINT_PREFIX")
                            {
                                WAYPOINT_PREFIX = value;
                                llOwnerSay("WAYPOINT_PREFIX: " + WAYPOINT_PREFIX);
                            }
                            else if (configKey == "API_ENDPOINT")
                            {
                                API_ENDPOINT = value;
                            }
                            else if (configKey == "API_KEY" || configKey == "SUBSCRIBER_KEY")
                            {
                                API_KEY = value;
                            }
                            else if (configKey == "MOVEMENT_SPEED")
                            {
                                MOVEMENT_SPEED = (float)value;
                            }
                            else if (configKey == "DOOR_DETECTION_ENABLED")
                            {
                                if (llToUpper(value) == "TRUE" || value == "1")
                                {
                                    DOOR_DETECTION_ENABLED = TRUE;
                                }
                                else
                                {
                                    DOOR_DETECTION_ENABLED = FALSE;
                                }
                            }
                            else if (configKey == "DOOR_NAME_PATTERN")
                            {
                                DOOR_NAME_PATTERN = value;
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
                                llOwnerSay("HOME_WAYPOINT: " + (string)HOME_WAYPOINT);
                            }
                            else if (configKey == "HOME_DURATION_MINUTES")
                            {
                                HOME_DURATION_MINUTES = (integer)value;
                                llOwnerSay("HOME_DURATION_MINUTES: " + (string)HOME_DURATION_MINUTES);
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
                // Finished reading RoseConfig
                llOwnerSay("Configuration loaded.");
                if (llGetListLength(available_attachables) > 0)
                {
                    llOwnerSay("Loaded " + (string)llGetListLength(available_attachables) + " attachables");
                }
                
                // Scan inventory for animations using naming convention
                scanInventoryAnimations();
                
                // Now load waypoint config
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
                            
                            // Parse position and JSON: <x,y,z>|{json} or just <x,y,z> for transient
                            integer pipePos = llSubStringIndex(value, "|");
                            if (pipePos != -1)
                            {
                                string posStr = llGetSubString(value, 0, pipePos - 1);
                                string jsonStr = llGetSubString(value, pipePos + 1, -1);
                                vector pos = (vector)posStr;
                                
                                // Parse JSON to check if transient
                                list wpData = parseWaypointJSON(jsonStr);
                                string wpType = llList2String(wpData, 0);
                                
                                if (wpType == "transient")
                                {
                                    // Store only wpNum and position for transient waypoints
                                    waypoint_configs += [wpNum, pos];
                                }
                                else
                                {
                                    // Store full parsed data for linger/sit waypoints
                                    // Format: [wpNum, pos, type, name, orientation, time, animation, attachments]
                                    waypoint_configs += [wpNum, pos] + wpData;
                                }
                            }
                            else
                            {
                                // No pipe means just a position vector (transient by default)
                                vector pos = (vector)value;
                                waypoint_configs += [wpNum, pos];
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
                // Count waypoints (variable length entries)
                integer configCount = 0;
                integer i;
                for (i = 0; i < llGetListLength(waypoint_configs); )
                {
                    integer wpNum = llList2Integer(waypoint_configs, i);
                    vector wpPos = llList2Vector(waypoint_configs, i + 1);
                    
                    // Check if next element is a string (type field) or integer (next wpNum)
                    if (i + 2 < llGetListLength(waypoint_configs))
                    {
                        string nextElem = llList2String(waypoint_configs, i + 2);
                        // If it's "transient", "linger", or "sit", it's a non-transient waypoint (8 elements)
                        if (nextElem == "transient" || nextElem == "linger" || nextElem == "sit")
                        {
                            i += 8; // Skip 8 elements for linger/sit
                        }
                        else
                        {
                            i += 2; // Skip 2 elements for transient
                        }
                    }
                    else
                    {
                        i += 2; // Last entry, must be transient
                    }
                    configCount++;
                }
                llOwnerSay("Loaded " + (string)configCount + " waypoints");
                initializeNavigation();
            }
        }
    }
    
    timer()
    {
        if (current_state == "WALKING")
        {
            // Check for navigation timeout
            if (llGetUnixTime() - navigation_start_time > NAVIGATION_TIMEOUT)
            {
                //llOwnerSay("NAV: Timeout after " + (string)NAVIGATION_TIMEOUT + "s, dist:" + 
                           //(string)llVecDist(llGetPos(), current_target_pos) + "m");
                // Stop keyframed motion
                llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
                stopWalkAnimation();
                is_navigating = FALSE;
                moveToNextWaypoint();
            }
            
            // Check if we've reached the target
            vector current_pos = llGetPos();
            float distance = llVecDist(current_pos, current_target_pos);
            
            if (distance < WAYPOINT_POSITION_TOLERANCE)
            {
                // Reached waypoint - stop keyframed motion and walk animation
                llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
                stopWalkAnimation();
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
    
    link_message(integer sender, integer num, string msg, key link_id)
    {
        if (num == LINK_WANDERING_STATE)
        {
            if (msg == "GREETING" || msg == "CHATTING")
            {
                // Stop wandering during interaction
                if (is_navigating)
                {
                    llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
                    stopWalkAnimation();
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
            toggleWander();
        }
        else if (llSubStringIndex(msg, "WHAT_DOING") == 0)
        {
            // Respond with current activity
            string response = "I'm currently " + current_activity_name;
            if (activity_type == "linger")
                response += " at " + llList2String(waypoint_configs, current_waypoint_index * 3 + 2);
            
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
            // Reset 429 counter on success
            if (error_429_count > 0)
            {
                error_429_count = 0;
            }
        }
        else if (status == 429)
        {
            // Rate limiting - suppress spam, only log summary periodically
            integer now = llGetUnixTime();
            error_429_count++;
            
            // Log only once per 5 minutes to avoid spam
            if (now - last_429_time > 300)
            {
                if (error_429_count > 1)
                {
                    llOwnerSay("API rate limit (429) - " + (string)error_429_count + " throttled");
                }
                else
                {
                    llOwnerSay("API rate limit (429). Will retry.");
                }
                last_429_time = now;
                error_429_count = 0;
            }
        }
        else
        {
            // Log other HTTP errors (these indicate real problems)
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
                llResetScript();
            }
            else if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) == INVENTORY_NOTECARD)
            {
                llResetScript();
            }
            else
            {
                // Rescan animations when inventory changes
                scanInventoryAnimations();
            }
        }
    }
}
