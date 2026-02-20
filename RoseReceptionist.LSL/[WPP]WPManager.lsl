// [WPP]WPManager.lsl
// Waypoint Manager - Determines next waypoint and manages activity state

// CONFIGURATION
string WAYPOINT_PREFIX = "Waypoint";

// Link messages - Navigation
integer LINK_NAV_GOTO = 4000;      // Waypoint->Navigator: Go to position
integer LINK_NAV_ARRIVED = 4001;   // Navigator->Waypoint: Arrived at waypoint
integer LINK_NAV_TIMEOUT = 4002;   // Navigator->Waypoint: Navigation timeout

// Link messages - Activity Reporting
integer LINK_ACTIVITY_START = 3010;    // Waypoint->Reporter: Activity started
integer LINK_ACTIVITY_COMPLETE = 3011; // Waypoint->Reporter: Activity completed
integer LINK_ACTIVITY_UPDATE = 2001;   // Waypoint->Main: Activity update
integer LINK_WANDERING_STATE = 2000;   // From other scripts

integer STAND_ANIMATION_INTERVAL = 5;
integer MAX_ACTIVITY_DURATION = 300;
integer STAY_IN_PARCEL = TRUE;
integer DOOR_DETECTION_ENABLED = TRUE;
string DOOR_NAME_PATTERN = "door";

integer HOME_WAYPOINT = 0;  // Default to waypoint 0
integer HOME_DURATION_MINUTES = 0;
integer loading_config = FALSE;  // Flag to prevent reset during config load

// Watchdog timer to prevent getting stuck
integer WATCHDOG_TIMEOUT = 600;  // 10 minutes maximum in any state
integer last_state_change_time = 0;
string last_known_state = "IDLE";

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

integer wander_enabled = TRUE;

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

// Update state and reset watchdog timer
updateState(string new_state)
{
    if (new_state != current_state)
    {
        current_state = new_state;
        last_state_change_time = llGetUnixTime();
        last_known_state = new_state;
    }
}

// Check if stuck in same state too long
checkWatchdog()
{
    integer time_in_state = llGetUnixTime() - last_state_change_time;
    
    if (time_in_state > WATCHDOG_TIMEOUT)
    {
        llOwnerSay("⚠️ WATCHDOG: Stuck in " + current_state + " for " + (string)time_in_state + "s - forcing next waypoint");
        
        // Stop any animations
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
        }
        stopStandAnimation();
        
        // Force move to next waypoint
        moveToNextWaypoint();
        
        // If still stuck after attempting to move, reset the script
        if (time_in_state > WATCHDOG_TIMEOUT * 2)
        {
            llOwnerSay("⚠️ WATCHDOG: Still stuck after " + (string)time_in_state + "s - resetting script");
            llResetScript();
        }
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
        updateState("IDLE");
        llSetTimerEvent(0.0);
    }
    else
    {
        loadWaypointConfig();
    }
}

loadWaypointConfig()
{
    if (llGetInventoryType(WAYPOINT_CONFIG_NOTECARD) == INVENTORY_NOTECARD)
    {
        loading_config = TRUE;  // Set flag to prevent reset during load
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
    
    // Notify other scripts
    if (activity_type != "transient" && current_activity_name != "")
    {
        llMessageLinked(LINK_SET, LINK_ACTIVITY_UPDATE, current_activity_name, NULL_KEY);
    }
    
    // Report to API via Reporter script
    if (activity_type != "transient")
    {
        // Send activity info to Reporter: msg=name, id=type|duration
        llMessageLinked(LINK_SET, LINK_ACTIVITY_START, current_activity_name, 
                       (key)(activity_type + "|" + (string)activity_duration));
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
        updateState("LINGERING");
    }
    else if (activity_type == "sit")
    {
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
        }
        
        updateState("SITTING");
        
        if (activity_duration > 0)
        {
            llSetTimerEvent((float)activity_duration);
        }
    }
}

moveToNextWaypoint()
{
    // Notify Reporter that activity completed
    if (current_activity_name != "" && current_activity_name != "idle")
    {
        llMessageLinked(LINK_SET, LINK_ACTIVITY_COMPLETE, current_activity_name, NULL_KEY);
    }
    
    integer num_waypoints = getWaypointCount();
    integer listLen = llGetListLength(waypoint_configs);
    if (num_waypoints == 0)
    {
        llOwnerSay("No wp configs (list len=" + (string)listLen + ")");
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
        
        // Check if blocked by door (simplified)
        if (DOOR_DETECTION_ENABLED)
        {
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
    updateState("WALKING");
    llMessageLinked(LINK_SET, LINK_NAV_GOTO, (string)target_pos, (key)((string)wpNumber));
}

// MAIN STATE
default
{
    state_entry()
    {
        llOwnerSay("Waypoint Manager ready");
        
        // Initialize watchdog timer
        last_state_change_time = llGetUnixTime();
        updateState("IDLE");
        
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
        // Always check watchdog first
        checkWatchdog();
        
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
                updateState("INTERACTING");
                llSetTimerEvent(0.0);
            }
            else if (msg == "DONE")
            {
                updateState("IDLE");
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
                        string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                        
                        // Case-insensitive WAYPOINT prefix check (handles WAYPOINT0 vs Waypoint0)
                        if (llSubStringIndex(llToUpper(configKey), llToUpper(WAYPOINT_PREFIX)) == 0)
                        {
                            integer wpNum = (integer)llGetSubString(configKey, llStringLength(WAYPOINT_PREFIX), -1);
                            
                            // Decode HTML entities that may have been introduced during copy/paste
                            value = llReplaceSubString(value, "&lt;", "<", 0);
                            value = llReplaceSubString(value, "&gt;", ">", 0);
                            value = llReplaceSubString(value, "&amp;", "&", 0);
                            value = llReplaceSubString(value, "&quot;", "\"", 0);
                            
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
                            else if (llGetSubString(value, 0, 0) == "{")
                            {
                                list wpData = parseWaypointJSON(value);
                                string wpType = llList2String(wpData, 0);
                                
                                if (wpType == "transient")
                                {
                                    waypoint_configs += [wpNum, ZERO_VECTOR];
                                }
                                else
                                {
                                    waypoint_configs += [wpNum, ZERO_VECTOR] + wpData;
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
                loading_config = FALSE;  // Clear flag - load complete
                integer configCount = getWaypointCount();
                integer listLen = llGetListLength(waypoint_configs);
                llOwnerSay((string)configCount + " waypoints (list len=" + (string)listLen + ")");
                moveToNextWaypoint();
            }
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            // Don't reset while loading config - let it complete first
            if (loading_config)
            {
                return;
            }
            
            // Otherwise, always reload configs on inventory change
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
