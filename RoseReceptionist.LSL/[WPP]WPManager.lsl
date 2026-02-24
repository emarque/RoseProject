// [WPP]WPManager.lsl
// Waypoint Manager - Determines next waypoint and manages activity state

// Debug mode
integer DEBUG = FALSE;  // Will be loaded from RoseConfig.txt

// Debug output function
debugSay(string msg)
{
    if (DEBUG)
    {
        llOwnerSay("[Manager] " + msg);
    }
}

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

// Link messages - Debug Status
integer LINK_DEBUG_STATUS_REQUEST = 9000;  // Main->Manager: Request status
integer LINK_DEBUG_STATUS_RESPONSE = 9001; // Manager->Main: Send status

integer STAND_ANIMATION_INTERVAL = 5;
integer MAX_ACTIVITY_DURATION = 300;
integer STAY_IN_PARCEL = TRUE;
integer DOOR_DETECTION_ENABLED = TRUE;
string DOOR_NAME_PATTERN = "door";

integer HOME_WAYPOINT = 0;  // Default to waypoint 0
integer HOME_DURATION_MINUTES = 5;
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
string activity_animation = "";  // Single animation (backward compatibility)
list activity_animations = [];    // List of animations to cycle through
integer activity_anim_interval = 30;  // Seconds between animation changes
integer current_anim_index = 0;   // Current animation in the list
integer last_anim_change_time = 0; // When we last changed animation
integer activity_orientation = -1;
integer activity_duration = 0;
integer activity_start_time = 0;

// Sit target finding
key sit_target_key = NULL_KEY;
integer waiting_for_sit_sensor = FALSE;
float buttOffset = 0.40;

// Schedule-based waypoint system
string SHIFT_START_TIME = "09:00";
string SHIFT_END_TIME = "17:00";
string NIGHT_START_TIME = "22:00";
string current_schedule_period = "";  // "WORK", "AFTER_WORK", "NIGHT"
integer last_schedule_check = 0;
integer SCHEDULE_CHECK_INTERVAL = 60;  // Check every 60 seconds
integer shift_end_announced = FALSE;  // Track if we've said goodbye
integer schedule_transition_teleport = FALSE;  // Flag to teleport after config load
integer timezone_offset = -8; //default to SLT

// Config notecards for different periods
string WORK_CONFIG = "[WPP]WaypointConfig";
string AFTER_WORK_CONFIG = "[WPP]AfterWorkConfig";
string NIGHT_CONFIG = "[WPP]NightConfig";
string active_config_name = "";

// Parse time string "HH:MM" to minutes since midnight
integer parseTimeToMinutes(string time_str)
{
    integer colon = llSubStringIndex(time_str, ":");
    if (colon == -1) return 0;
    
    integer hours = (integer)llGetSubString(time_str, 0, colon - 1);
    integer minutes = (integer)llGetSubString(time_str, colon + 1, -1);
    
    return hours * 60 + minutes;
}

string  sbGetTimestamp(integer intOffset) {
    // Start with December for purposes of wrapping
    list    lstDays  = [31, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    string  strTimestamp = llGetTimestamp();

    list    lstTime  = llParseString2List(strTimestamp, ["-", ":", ".", "T"], []);
    integer intYear  = llList2Integer(lstTime, 0);
    integer intMonth = llList2Integer(lstTime, 1);
    integer intDay   = llList2Integer(lstTime, 2);
    integer intHour  = llList2Integer(lstTime, 3);

    string  strYear;
    string  strMonth;
    string  strDay;
    string  strHour;

    if (intOffset == 0) { return strTimestamp; }

    if (intOffset < -24 || intOffset > 24) {
        intOffset = ((integer)llGetWallclock() - (integer)llGetGMTclock()) / 3600;
    }

    intHour+= intOffset;

    // Add a day to February in leap years
    if (intYear % 4 == 0 && (intYear % 100 != 0 || intYear % 400 == 0)) {
        lstDays = llListReplaceList(lstDays, [29], 2, 2);
    }

    if (intOffset < 0) {
        if (intHour < 0) { 
            intHour+= 24;
            --intDay;
        }

        if (intDay < 1) {
            intDay = llList2Integer(lstDays, --intMonth);
        }

        if (intMonth < 1) {
            intMonth = 12;
            --intYear;
        }
    }

    if (intOffset > 0) {
        if (intHour > 23) {
            intHour-= 24;
            ++intDay;
        }

        if (intDay > llList2Integer(lstDays, intMonth)) {
            intDay = 1;
            ++intMonth;
        }

        if (intMonth > 12) {
            intMonth = 1;
            ++intYear;
        }
    }

    strYear  = (string)intYear;
    strMonth = (string)intMonth;
    strDay   = (string)intDay;
    strHour  = (string)intHour;

    if (llStringLength(strMonth) < 2) { strMonth = "0" + strMonth; }
    if (llStringLength(strDay)   < 2) { strDay   = "0" + strDay;   }
    if (llStringLength(strHour)  < 2) { strHour  = "0" + strHour;  }

    return
        strYear                   + "-" + 
        strMonth                  + "-" + 
        strDay                    + "T" + 
        strHour                   + ":" + 
        llList2String(lstTime, 4) + ":" + 
        llList2String(lstTime, 5) + "." + 
        llList2String(lstTime, 6) + "Z";
        // Obviously this isn't really Z time anymore, but I left it there in case there
        // are scripts expecting it.
}

// Get current SL time in minutes since midnight
integer getCurrentTimeMinutes()
{
    string timestamp = sbGetTimestamp(timezone_offset); // adjusts for timezone automatically
    // Format: YYYY-MM-DDTHH:MM:SS.ffffffZ
    integer tpos = llSubStringIndex(timestamp, "T");
    string timepart = llGetSubString(timestamp, tpos + 1, tpos + 8);  // HH:MM:SS
    
    integer hours = (integer)llGetSubString(timepart, 0, 1);
    integer minutes = (integer)llGetSubString(timepart, 3, 4);
    return hours * 60 + minutes;
}

// Determine which schedule period we're in
string getCurrentSchedulePeriod()
{
    integer current_minutes = getCurrentTimeMinutes();
    integer shift_start = parseTimeToMinutes(SHIFT_START_TIME);
    integer shift_end = parseTimeToMinutes(SHIFT_END_TIME);
    integer night_start = parseTimeToMinutes(NIGHT_START_TIME);
    
    // Handle the three periods
    if (current_minutes >= shift_start && current_minutes < shift_end)
    {
        return "WORK";
    }
    else if (current_minutes >= shift_end && current_minutes < night_start)
    {
        return "AFTER_WORK";
    }
    else
    {
        // Night period (night_start to shift_start, possibly crossing midnight)
        return "NIGHT";
    }
}

// Get config notecard name for current period
string getConfigForPeriod(string period)
{
    if (period == "WORK")
    {
        return WORK_CONFIG;
    }
    else if (period == "AFTER_WORK")
    {
        return AFTER_WORK_CONFIG;
    }
    else if (period == "NIGHT")
    {
        return NIGHT_CONFIG;
    }
    return WORK_CONFIG;  // Fallback
}

// Calculate seconds until current period ends
integer getSecondsUntilPeriodEnd()
{
    integer current_minutes = getCurrentTimeMinutes();
    integer shift_start = parseTimeToMinutes(SHIFT_START_TIME);
    integer shift_end = parseTimeToMinutes(SHIFT_END_TIME);
    integer night_start = parseTimeToMinutes(NIGHT_START_TIME);
    
    string period = getCurrentSchedulePeriod();
    integer period_end_minutes;
    
    if (period == "WORK")
    {
        period_end_minutes = shift_end;
    }
    else if (period == "AFTER_WORK")
    {
        period_end_minutes = night_start;
    }
    else // NIGHT
    {
        period_end_minutes = shift_start;
        // If we're past midnight and shift starts tomorrow
        if (current_minutes < period_end_minutes)
        {
            // We're already into the next day, period ends at shift_start
            return (period_end_minutes - current_minutes) * 60;
        }
        else
        {
            // Period ends tomorrow at shift_start
            return ((1440 - current_minutes) + period_end_minutes) * 60;
        }
    }
    
    // For WORK and AFTER_WORK periods
    if (period_end_minutes > current_minutes)
    {
        return (period_end_minutes - current_minutes) * 60;
    }
    else
    {
        // Period ends tomorrow (shouldn't happen normally, but handle it)
        return ((1440 - current_minutes) + period_end_minutes) * 60;
    }
}

// Check if schedule has changed and handle transition
checkScheduleTransition()
{
    integer now = llGetUnixTime();
    if (now - last_schedule_check < SCHEDULE_CHECK_INTERVAL)
    {
        return;  // Don't check too frequently
    }
    
    last_schedule_check = now;
    string new_period = getCurrentSchedulePeriod();
    
    if (new_period != current_schedule_period)
    {
        // Schedule transition detected!
        debugSay("⏰ Schedule transition: " + current_schedule_period + " → " + new_period);
        
        // Handle shift end announcement
        if (current_schedule_period == "WORK" && new_period == "AFTER_WORK")
        {
            announceEndOfShift();
        }
        else if (new_period == "WORK" && current_schedule_period == "NIGHT")
        {
            llSay(0, "Good morning everyone! I'm back at work.");
            shift_end_announced = FALSE;  // Reset for next shift
        }
        
        current_schedule_period = new_period;
        
        // Switch to appropriate waypoint config
        switchWaypointConfig(new_period);
    }
}

// Announce end of shift
announceEndOfShift()
{
    if (!shift_end_announced)
    {
        llSay(0, "Well everyone, my shift is over! I'll see you all tomorrow. Have a great evening!");
        shift_end_announced = TRUE;
    }
}

// Switch to different waypoint configuration
switchWaypointConfig(string period)
{
    string new_config = getConfigForPeriod(period);
    
    if (new_config != active_config_name)
    {
        llOwnerSay("Switching to " + period + " waypoint config: " + new_config);
        
        // Stop current activity
        if (activity_animation != "")
        {
            llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
        }
        
        // Stop all animation cycling
        if (llGetListLength(activity_animations) > 0)
        {
            integer i;
            for (i = 0; i < llGetListLength(activity_animations); i++)
            {
                string anim = llList2String(activity_animations, i);
                if (anim != "")
                {
                    llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + anim, NULL_KEY);
                }
            }
        }
        
        stopStandAnimation();
        
        if (current_state == "SITTING")
        {
            sit_target_key = NULL_KEY;
        }
        
        // Update state to IDLE to prevent freeze
        updateState("IDLE");
        llSetTimerEvent(0.0);  // Stop timer temporarily
        
        // Clear activity data
        activity_animation = "";
        activity_animations = [];
        current_activity_name = "";
        
        // Update config name
        WAYPOINT_CONFIG_NOTECARD = new_config;
        active_config_name = new_config;
        
        // Reset waypoint index
        current_waypoint_index = -1;
        
        // Set flag to teleport to first waypoint after config loads
        schedule_transition_teleport = TRUE;
        
        // Load new config
        loadWaypointConfig();
    }
}

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
    
    // Parse animations (support both array and single string)
    string animationsStr = "";
    integer animsStart = llSubStringIndex(json, "\"animations\":[");
    if (animsStart != -1)
    {
        // New format: array of animations
        animsStart += 14;
        integer animsEnd = llSubStringIndex(llGetSubString(json, animsStart, animsStart + 300), "]");
        if (animsEnd != -1)
        {
            animationsStr = llGetSubString(json, animsStart, animsStart + animsEnd - 1);
        }
    }
    else
    {
        // Old format: single animation string (backward compatibility)
        integer animStart = llSubStringIndex(json, "\"animation\":\"");
        if (animStart != -1)
        {
            animStart += 13;
            integer animEnd = llSubStringIndex(llGetSubString(json, animStart, animStart + 50), "\"");
            if (animEnd != -1)
            {
                animationsStr = llGetSubString(json, animStart, animStart + animEnd - 1);
            }
        }
    }
    
    // Parse animInterval (default 30 seconds)
    integer animInterval = 30;
    integer intervalStart = llSubStringIndex(json, "\"animInterval\":");
    if (intervalStart != -1)
    {
        intervalStart += 15;
        string intervalSubstr = llGetSubString(json, intervalStart, intervalStart + 10);
        integer commaPos = llSubStringIndex(intervalSubstr, ",");
        integer bracePos = llSubStringIndex(intervalSubstr, "}");
        integer endPos = commaPos;
        if (endPos == -1 || (bracePos != -1 && bracePos < endPos))
            endPos = bracePos;
        
        if (endPos != -1)
        {
            animInterval = (integer)llGetSubString(intervalSubstr, 0, endPos - 1);
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
    
    // Return: type, name, orientation, time, animationsStr, animInterval, attachJson
    return [type, name, orientation, time, animationsStr, animInterval, attachJson];
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
        waypointConfigLine = 0;
        waypoint_configs = [];
        waypointConfigQuery = llGetNotecardLine(WAYPOINT_CONFIG_NOTECARD, waypointConfigLine);
    }
}

// Get waypoint entry size in list
integer getWaypointEntrySize(integer listIdx)
{
    if (listIdx + 2 < llGetListLength(waypoint_configs))
    {
        if (llGetListEntryType(waypoint_configs, listIdx + 2) == TYPE_STRING)
        {
            // Check if this is new format (9 elements) or old format (8 elements)
            // New format: wpNum, pos, type, name, orientation, time, animationsStr, animInterval, attachJson
            // Old format: wpNum, pos, type, name, orientation, time, anim, attachJson
            if (listIdx + 8 < llGetListLength(waypoint_configs) &&
                llGetListEntryType(waypoint_configs, listIdx + 7) == TYPE_INTEGER)
            {
                return 9;  // New format with animInterval
            }
            return 8;  // Old format
        }
    }
    return 2;
}

// Parse animations string into list
list parseAnimationsList(string animStr)
{
    list result = [];
    
    if (animStr == "") return result;
    
    // Check if it's a comma-separated list (from JSON array)
    if (llSubStringIndex(animStr, ",") != -1)
    {
        // Parse each animation from the comma-separated list
        list parts = llParseString2List(animStr, [","], []);
        integer i;
        for (i = 0; i < llGetListLength(parts); i++)
        {
            string anim = llStringTrim(llList2String(parts, i), STRING_TRIM);
            // Remove quotes if present
            if (llGetSubString(anim, 0, 0) == "\"")
            {
                anim = llGetSubString(anim, 1, -2);
            }
            if (anim != "")
            {
                result += [anim];
            }
        }
    }
    else
    {
        // Single animation - just trim and remove quotes
        animStr = llStringTrim(animStr, STRING_TRIM);
        if (llGetSubString(animStr, 0, 0) == "\"")
        {
            animStr = llGetSubString(animStr, 1, -2);
        }
        if (animStr != "")
        {
            result = [animStr];
        }
    }
    
    return result;
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
            if (entrySize == 9)
            {
                // New format with animations list and animInterval
                return [llList2String(waypoint_configs, listIdx + 2),
                        llList2String(waypoint_configs, listIdx + 3),
                        llList2Integer(waypoint_configs, listIdx + 4),
                        llList2Integer(waypoint_configs, listIdx + 5),
                        llList2String(waypoint_configs, listIdx + 6),
                        llList2Integer(waypoint_configs, listIdx + 7),
                        llList2String(waypoint_configs, listIdx + 8)];
            }
            else if (entrySize == 8)
            {
                // Old format - convert to new format with default animInterval
                return [llList2String(waypoint_configs, listIdx + 2),
                        llList2String(waypoint_configs, listIdx + 3),
                        llList2Integer(waypoint_configs, listIdx + 4),
                        llList2Integer(waypoint_configs, listIdx + 5),
                        llList2String(waypoint_configs, listIdx + 6),
                        30,  // Default animInterval
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
        string animationsStr = llList2String(configData, 4);
        activity_anim_interval = llList2Integer(configData, 5);
        attachments_json = llList2String(configData, 6);
        
        // Parse animations list
        activity_animations = parseAnimationsList(animationsStr);
        if (llGetListLength(activity_animations) > 0)
        {
            activity_animation = llList2String(activity_animations, 0);
            current_anim_index = 0;
            last_anim_change_time = llGetUnixTime();
        }
        else
        {
            activity_animation = "";
        }
    }
    else
    {
        activity_type = "transient";
        current_activity_name = "";
        activity_orientation = -1;
        activity_duration = 0;
        activity_animation = "";
        activity_animations = [];
        activity_anim_interval = 30;
        attachments_json = "";
    }
    
    if (wpNumber == HOME_WAYPOINT)
    {
        activity_duration = (HOME_DURATION_MINUTES * 60); // minutes to seconds
        debugSay("Duration set to: " + (string)(HOME_DURATION_MINUTES * 60) + "seconds");
    }
    
    // If this is the only waypoint in the period, set duration to match period end
    integer num_waypoints = getWaypointCount();
    if (num_waypoints == 1 && activity_type != "transient")
    {
        integer seconds_until_end = getSecondsUntilPeriodEnd();
        // Only override if calculated time is reasonable (more than 1 minute, less than 24 hours)
        if (seconds_until_end > 60 && seconds_until_end < 86400)
        {
            activity_duration = seconds_until_end;
            debugSay("Single activity - duration set to period end: " + (string)activity_duration + "s (" + 
                      (string)(activity_duration / 60) + " minutes)");
        }
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
        
        // Face direction if specified - apply rotation around Z-axis only to keep upright
        if (activity_orientation != -1)
        {
            float radians = activity_orientation * DEG_TO_RAD;
            // Rotation around Z-axis only (yaw), keeping pitch=0 and roll=0
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
        llOwnerSay("Activity: " + current_activity_name + " (" + (string)activity_duration + "s)");
        
        // Find closest prim labeled "sit"
        waiting_for_sit_sensor = TRUE;
        llSensorRepeat("", NULL_KEY, PASSIVE|ACTIVE, 2.0, PI, 1.0);
        
        // Play animation if specified
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
        debugSay("No wp configs (list len=" + (string)listLen + ")");
        llSetTimerEvent(30.0);
        return;
    }
    
    // Home position logic
//    if (HOME_WAYPOINT >= 0 && !loop_started)
//    {
//        integer home_index = findWaypointIndexByNumber(HOME_WAYPOINT);
//        if (home_index == -1)
//        {
//            llOwnerSay("Home wp " + (string)HOME_WAYPOINT + " not found");
//        }
//        else
//        {
//            current_waypoint_index = home_index;
//            at_home = TRUE;
//            home_start_time = llGetUnixTime();
//            loop_started = FALSE;
            
//            navigateToCurrentWaypoint();
//            return;
//        }
//    }
    
    // Check if at home
//    if (at_home && HOME_DURATION_MINUTES > 0)
//    {
//        integer elapsed_minutes = (llGetUnixTime() - home_start_time) / 60;
//        if (elapsed_minutes < HOME_DURATION_MINUTES)
//        {
//            llSetTimerEvent(60.0);
//            return;
//        }
//        else
//        {
//            at_home = FALSE;
//            loop_started = TRUE;
//        }
//    }
    
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
    
    // Check if this is a schedule transition teleport
    if (schedule_transition_teleport)
    {
        schedule_transition_teleport = FALSE;
        
        // Use llSetRegionPos for instant teleport
        // llSetRegionPos can move up to 10m per call
        vector current_pos = llGetPos();
        vector distance_vec = target_pos - current_pos;
        float distance = llVecMag(distance_vec);
        
        if (distance > 10.0)
        {
            // Need multiple jumps
            integer jumps = (integer)(distance / 10.0) + 1;
            vector step = distance_vec / (float)jumps;
            integer i;
            for (i = 0; i < jumps; i++)
            {
                vector next_pos = current_pos + step * (float)(i + 1);
                integer success = llSetRegionPos(next_pos);
                if (!success)
                {
                    // Failed - fall back to normal navigation
                    updateState("WALKING");
                    llMessageLinked(LINK_SET, LINK_NAV_GOTO, (string)target_pos, (key)((string)wpNumber));
                    return;
                }
            }
        }
        else
        {
            // Single jump
            integer success = llSetRegionPos(target_pos);
            if (!success)
            {
                // Failed - fall back to normal navigation
                updateState("WALKING");
                llMessageLinked(LINK_SET, LINK_NAV_GOTO, (string)target_pos, (key)((string)wpNumber));
                return;
            }
        }
        
        // Teleport successful - process waypoint immediately
        processWaypoint(target_pos);
    }
    else
    {
        // Normal navigation
        updateState("WALKING");
        llMessageLinked(LINK_SET, LINK_NAV_GOTO, (string)target_pos, (key)((string)wpNumber));
    }
}

sit()
{
    // Now sit on the target
    if (sit_target_key != NULL_KEY)
    {
        list details = llGetObjectDetails(sit_target_key, [OBJECT_POS, OBJECT_ROT]);
        if (details != [])
        {
            vector pos = llList2Vector(details, 0);
            //llOwnerSay("pos.z = " + (string)pos.z + " new pos.z=" + (string)(pos.z+0.6));
            pos.z = pos.z + buttOffset; //The "butt" offset
            rotation rot = llList2Rot(details, 1);
            llSetPos(pos);
            llSetRot(rot);
            debugSay("Sitting on target");
        }
    }
}

// MAIN STATE
default
{
    state_entry()
    {
        debugSay("Waypoint Manager ready");
        
        // Initialize watchdog timer
        last_state_change_time = llGetUnixTime();
        updateState("IDLE");
        
        // Initialize schedule system
        current_schedule_period = getCurrentSchedulePeriod();
        active_config_name = getConfigForPeriod(current_schedule_period);
        WAYPOINT_CONFIG_NOTECARD = active_config_name;
        
        // Set up debug listener if DEBUG mode
        if (DEBUG)
        {
            llListen(-9876, "", NULL_KEY, "");
        }
        
        if (llGetInventoryType(notecardName) == INVENTORY_NOTECARD)
        {
            notecardLine = 0;
            notecardQuery = llGetNotecardLine(notecardName, notecardLine);
        }
        else
        {
            scanInventoryAnimations();
            loadWaypointConfig();
        }
    }
    
    timer()
    {
        // Always check watchdog first
        checkWatchdog();
        
        // Check for schedule transitions
        checkScheduleTransition();
        
        if (current_state == "LINGERING" || current_state == "SITTING" || current_state == "INTERACTING")
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
                
                // Unsit if we're sitting or interacting
                if (current_state == "SITTING" || current_state == "INTERACTING")
                {
                    sit_target_key = NULL_KEY;
                }
                
                moveToNextWaypoint();
                return;  // Prevent double call to moveToNextWaypoint
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
                
                // Unsit if we're sitting or interacting
                if (current_state == "SITTING" || current_state == "INTERACTING")
                {
                    sit_target_key = NULL_KEY;
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
            else if (llGetListLength(activity_animations) > 1 && activity_anim_interval > 0)
            {
                // Multiple animations - cycle through them
                integer time_since_anim_change = llGetUnixTime() - last_anim_change_time;
                if (time_since_anim_change >= activity_anim_interval)
                {
                    // Stop current animation
                    if (activity_animation != "")
                    {
                        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + activity_animation, NULL_KEY);
                    }
                    
                    // Move to next animation
                    current_anim_index = (current_anim_index + 1) % llGetListLength(activity_animations);
                    activity_animation = llList2String(activity_animations, current_anim_index);
                    last_anim_change_time = llGetUnixTime();
                    
                    // Start new animation
                    if (activity_animation != "")
                    {
                        llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + activity_animation, NULL_KEY);
                    }
                }
                
                // Set timer for next animation change
                integer time_until_duration = activity_duration - elapsed;
                integer time_until_next_anim = activity_anim_interval - time_since_anim_change;
                float timer_interval = (float)time_until_next_anim;
                if (time_until_duration < time_until_next_anim)
                {
                    timer_interval = (float)time_until_duration;
                }
                if (timer_interval > 0.0)
                {
                    llSetTimerEvent(timer_interval);
                }
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
                // Keep timer running to check for activity completion and schedule transitions
                llSetTimerEvent(5.0);
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
        else if (num == LINK_DEBUG_STATUS_REQUEST)
        {
            // Build status report (optimized for memory)
            string status = "=== STATUS ===|";
            status += "State: " + current_state + "|";
            status += "WP: " + (string)current_waypoint_index + "/" + (string)getWaypointCount() + "|";
            status += "Activity: " + current_activity_name + "|";
            status += "Type: " + activity_type + "|";
            status += "Duration: " + (string)activity_duration + "s|";
            
            integer elapsed = llGetUnixTime() - activity_start_time;
            status += "Elapsed: " + (string)elapsed + "s|Remaining: " + (string)(activity_duration - elapsed) + "s|";
            
            status += "Period: " + current_schedule_period + "|";
            status += "Config: " + active_config_name + "|";
            
            if (llGetListLength(activity_animations) > 0)
            {
                status += "Anims: " + (string)llGetListLength(activity_animations) + " @ " + (string)activity_anim_interval + "s|";
                status += "Anim Idx: " + (string)current_anim_index + "|";
            }
            else if (activity_animation != "")
            {
                status += "Anim: " + activity_animation + "|";
            }
            else
            {
                status += "Anim: None|";
            }
            
            status += "Stand: " + current_stand_animation + "|";
            status += "Home: " + (string)at_home + "|Loop: " + (string)loop_started + "|";
            
            integer time_in_state = llGetUnixTime() - last_state_change_time;
            status += "StateTime: " + (string)time_in_state + "s|";
            status += "Watchdog: " + (string)WATCHDOG_TIMEOUT + "s|";
            
            if (current_state == "WALKING")
            {
                status += "Waiting: NAV_ARRIVED|";
            }
            else if (current_state == "LINGERING" || current_state == "SITTING")
            {
                status += "Waiting: Timer|";
            }
            else if (current_state == "IDLE")
            {
                status += "Waiting: moveToNextWP|";
            }
            else
            {
                status += "Waiting: Event|";
            }
            
            status += "===";
            
            // Send status back to Main via link message
            llMessageLinked(LINK_SET, LINK_DEBUG_STATUS_RESPONSE, status, NULL_KEY);
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
                            else if (configKey == "NIGHT_START_TIME")
                            {
                                NIGHT_START_TIME = value;
                            }
                            else if (configKey == "TIMEZONE_OFFSET")
                            {
                                timezone_offset = (integer)value;
                            }
                        }
                    }
                }
                
                ++notecardLine;
                notecardQuery = llGetNotecardLine(notecardName, notecardLine);
            }
            else
            {
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
    
    sensor(integer num)
    {
        if (!waiting_for_sit_sensor) return;
        
        // Find closest prim with "sit" in its name
        integer i;
        float closest_distance = 999.0;
        key closest_key = NULL_KEY;
        
        for (i = 0; i < num; i++)
        {
            string name = llToLower(llDetectedName(i));
            if (llSubStringIndex(name, "sit") != -1)
            {
                float distance = llVecDist(llGetPos(), llDetectedPos(i));
                if (distance < closest_distance)
                {
                    closest_distance = distance;
                    closest_key = llDetectedKey(i);
                }
            }
        }
        
        if (closest_key != NULL_KEY)
        {
            sit_target_key = closest_key;
            debugSay("Found sit target: " + llKey2Name(sit_target_key));
            sit();
        }
        else
        {
            debugSay("No 'sit' prim found nearby");
        }
        
        waiting_for_sit_sensor = FALSE;
        llSensorRemove();
    }
    
    no_sensor()
    {
        if (waiting_for_sit_sensor)
        {
            debugSay("No 'sit' prim found nearby");
            waiting_for_sit_sensor = FALSE;
            llSensorRemove();
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
