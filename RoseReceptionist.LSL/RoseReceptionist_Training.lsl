// RoseReceptionist_Training.lsl
// Interactive Training Wizard for Rose Receptionist Waypoint Configuration
// Allows users to configure waypoints through dialog menus

// ============================================================================
// CONFIGURATION
// ============================================================================

string WAYPOINT_PREFIX = "Waypoint";
float SENSOR_RANGE = 50.0;

// Link messages
integer LINK_TRAINING_START = 3000;
integer LINK_TRAINING_COMPLETE = 3001;

// ============================================================================
// STATE VARIABLES
// ============================================================================

// Training state machine
string training_state = "IDLE"; // IDLE, SCANNING, TYPE, DURATION, ANIMATION, ORIENTATION, ATTACHMENTS, COMPLETE
integer current_waypoint_index = 0;
list found_waypoints = []; // List of [prim_key, number, name, position]
list waypoint_configs = []; // List of JSON strings for each waypoint

// Current waypoint being configured
integer current_wp_number = -1;
string current_wp_name = "";
string current_wp_type = "";
integer current_wp_duration = 0;
string current_wp_animation = "";
integer current_wp_orientation = -1;
list current_wp_attachments = [];

// Training user
key training_user = NULL_KEY;
string training_user_name = "";

// Authorization
list OWNER_UUIDS = [];
string RECEPTIONIST_NAME = "Rose";

// Training mode
string training_mode = "REPLACE"; // REPLACE or APPEND
integer existing_waypoint_count = 0;
integer waypoint_number_offset = 0;

// Dialog channels and listeners
integer dialog_channel = 0;
integer dialog_listener = 0;
integer textbox_channel = 0;
integer textbox_listener = 0;

// Notecard reading for config
key notecardQuery;
integer notecardLine = 0;
string config_notecard_being_read = ""; // Track which notecard we're reading

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Check if user is authorized for training
integer isAuthorizedTrainer(key user)
{
    // Check if user is owner
    if (user == llGetOwner())
    {
        return TRUE;
    }
    
    // Check if user is in OWNER_UUIDS list
    if (llListFindList(OWNER_UUIDS, [(string)user]) != -1)
    {
        return TRUE;
    }
    
    return FALSE;
}

// Count existing waypoint configurations
integer countExistingWaypoints()
{
    if (llGetInventoryType("[WPP]WaypointConfig") != INVENTORY_NOTECARD)
    {
        return 0;
    }
    
    // Read notecard to count WAYPOINT entries
    existing_waypoint_count = 0;
    config_notecard_being_read = "[WPP]WaypointConfig";
    notecardLine = 0;
    notecardQuery = llGetNotecardLine(config_notecard_being_read, notecardLine);
    
    return -1; // Signal that we're counting asynchronously
}

// Extract number from waypoint name
integer extractWaypointNumber(string name)
{
    integer prefixPos = llSubStringIndex(name, WAYPOINT_PREFIX);
    if (prefixPos != -1)
    {
        string numStr = llGetSubString(name, prefixPos + llStringLength(WAYPOINT_PREFIX), -1);
        // Trim spaces
        numStr = llStringTrim(numStr, STRING_TRIM);
        return (integer)numStr;
    }
    return -1;
}

// Sort waypoints by number
list sortWaypointsByNumber(list wp)
{
    integer i;
    integer j;
    integer n = llGetListLength(wp) / 4;
    
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
                integer num_a = llList2Integer(wp, j * 4 + 1);
                string name1 = llList2String(wp, j * 4 + 2);
                vector pos1 = llList2Vector(wp, j * 4 + 3);
                
                key key2 = llList2Key(wp, (j + 1) * 4);
                integer num_b = llList2Integer(wp, (j + 1) * 4 + 1);
                string name2 = llList2String(wp, (j + 1) * 4 + 2);
                vector pos2 = llList2Vector(wp, (j + 1) * 4 + 3);
                
                wp = llListReplaceList(wp, [key2, num_b, name2, pos2], j * 4, j * 4 + 3);
                wp = llListReplaceList(wp, [key1, num_a, name1, pos1], (j + 1) * 4, (j + 1) * 4 + 3);
            }
        }
    }
    
    return wp;
}

// Generate JSON for current waypoint
string generateWaypointJSON()
{
    string json = "{\"type\":\"" + current_wp_type + "\"";
    
    // Add name (use waypoint prim name if not set)
    if (current_wp_name == "")
    {
        current_wp_name = "waypoint " + (string)(current_wp_number + waypoint_number_offset);
    }
    json += ",\"name\":\"" + current_wp_name + "\"";
    
    // Add orientation if set
    if (current_wp_orientation != -1)
    {
        json += ",\"orientation\":" + (string)current_wp_orientation;
    }
    
    // Add time if linger or sit
    if ((current_wp_type == "linger" || current_wp_type == "sit") && current_wp_duration > 0)
    {
        json += ",\"time\":" + (string)current_wp_duration;
    }
    
    // Add animation if set
    if (current_wp_animation != "")
    {
        json += ",\"animation\":\"" + current_wp_animation + "\"";
    }
    
    // Add attachments if any
    json += ",\"attachments\":[";
    integer i;
    integer attachCount = llGetListLength(current_wp_attachments);
    for (i = 0; i < attachCount; i += 2)
    {
        if (i > 0) json += ",";
        string item = llList2String(current_wp_attachments, i);
        string point = llList2String(current_wp_attachments, i + 1);
        json += "{\"item\":\"" + item + "\",\"point\":\"" + point + "\"}";
    }
    json += "]";
    
    json += "}";
    return json;
}

// Clear listeners
clearListeners()
{
    if (dialog_listener != 0)
    {
        llListenRemove(dialog_listener);
        dialog_listener = 0;
    }
    if (textbox_listener != 0)
    {
        llListenRemove(textbox_listener);
        textbox_listener = 0;
    }
}

// ============================================================================
// TRAINING FLOW FUNCTIONS
// ============================================================================

startTraining(key user, string userName)
{
    // Check authorization first
    if (!isAuthorizedTrainer(user))
    {
        llRegionSayTo(user, 0, "Sorry, I'm not authorized to take training from anyone but my managers, but I'd be happy to let them know you think I need training.");
        llOwnerSay("⚠️ " + userName + " attempted to access training mode but was not authorized.");
        return;
    }
    
    training_user = user;
    training_user_name = userName;
    
    // Check for existing configuration
    integer existingCount = countExistingWaypoints();
    
    if (existingCount == -1)
    {
        // Counting asynchronously, will continue in dataserver
        training_state = "COUNTING";
        llOwnerSay("🎓 Training Mode requested by " + userName + " - checking existing configuration...");
    }
    else if (existingCount == 0)
    {
        // No existing config, proceed directly to scanning
        training_state = "SCANNING";
        training_mode = "REPLACE";
        waypoint_number_offset = 0;
        llOwnerSay("🎓 Training Mode activated by " + userName);
        llRegionSayTo(user, 0, "Starting training mode! Scanning for " + WAYPOINT_PREFIX + " prims...");
        llSensor("", NULL_KEY, PASSIVE | ACTIVE, SENSOR_RANGE, PI);
    }
}

showTrainingModeMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "🎓 Training Mode\n\n";
    message += "Found " + (string)existing_waypoint_count + " existing waypoint configurations.\n\n";
    message += "How would you like to proceed?";
    
    llDialog(training_user, message,
        ["Replace All", "Add New", "Cancel"],
        dialog_channel);
    
    training_state = "MODE_SELECT";
    llSetTimerEvent(60.0);
}

showTypeMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "📍 Configuring " + WAYPOINT_PREFIX + (string)current_wp_number + 
                     "\n\nWhat type of waypoint is this?";
    
    llDialog(training_user, message,
        ["Transient", "Linger", "Sit"],
        dialog_channel);
    
    training_state = "TYPE";
    llSetTimerEvent(60.0); // Menu timeout
}

showDurationMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "⏱️ " + WAYPOINT_PREFIX + (string)current_wp_number + 
                     "\n\nHow long should I stay here?";
    
    llDialog(training_user, message,
        ["15s", "30s", "60s", "120s", "Custom", "Skip"],
        dialog_channel);
    
    training_state = "DURATION";
    llSetTimerEvent(60.0);
}

showAnimationMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "🎭 " + WAYPOINT_PREFIX + (string)current_wp_number + 
                     "\n\nSelect an animation:";
    
    // Get animations from inventory
    list anims = [];
    integer i;
    integer count = llGetInventoryNumber(INVENTORY_ANIMATION);
    
    for (i = 0; i < count && i < 11; i++)
    {
        string animName = llGetInventoryName(INVENTORY_ANIMATION, i);
        // Shorten name for button (max 24 chars)
        if (llStringLength(animName) > 20)
        {
            animName = llGetSubString(animName, 0, 19);
        }
        anims += [animName];
    }
    
    // Add None option
    anims += ["None"];
    
    // Ensure we have at least 1 button (None)
    if (llGetListLength(anims) == 0)
    {
        anims = ["None"];
    }
    
    llDialog(training_user, message, anims, dialog_channel);
    
    training_state = "ANIMATION";
    llSetTimerEvent(60.0);
}

showOrientationMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "🧭 " + WAYPOINT_PREFIX + (string)current_wp_number + 
                     "\n\nWhich direction should I face?";
    
    llDialog(training_user, message,
        ["North (90°)", "East (0°)", "South (270°)", "West (180°)", "None"],
        dialog_channel);
    
    training_state = "ORIENTATION";
    llSetTimerEvent(60.0);
}

showAttachmentsMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "📎 " + WAYPOINT_PREFIX + (string)current_wp_number + 
                     "\n\nSelect objects to attach:\n(Currently simplified - attachments coming soon)";
    
    llDialog(training_user, message,
        ["Done", "Skip"],
        dialog_channel);
    
    training_state = "ATTACHMENTS";
    llSetTimerEvent(60.0);
}

finalizeWaypoint()
{
    vector wpPos = llList2Vector(found_waypoints, current_waypoint_index * 4 + 3);
    string json = generateWaypointJSON();
    integer outputNumber = current_wp_number + waypoint_number_offset;
    string configLine = "WAYPOINT" + (string)outputNumber + "=" + (string)wpPos + "|" + json;
    waypoint_configs += [configLine];
    
    current_waypoint_index++;
    if (current_waypoint_index * 4 < llGetListLength(found_waypoints))
    {
        resetCurrentWaypoint();
        current_wp_number = llList2Integer(found_waypoints, current_waypoint_index * 4 + 1);
        showTypeMenu();
    }
    else
    {
        completeTraining();
    }
}

resetCurrentWaypoint()
{
    current_wp_name = "";
    current_wp_type = "";
    current_wp_duration = 0;
    current_wp_animation = "";
    current_wp_orientation = -1;
    current_wp_attachments = [];
}

completeTraining()
{
    training_state = "COMPLETE";
    clearListeners();
    llSetTimerEvent(0.0);
    
    llRegionSayTo(training_user, 0, "✅ Training complete! Copy config below:");
    
    string allConfigs = "\n";
    integer i;
    for (i = 0; i < llGetListLength(waypoint_configs); i++)
    {
        allConfigs += llList2String(waypoint_configs, i);
        if (i < llGetListLength(waypoint_configs) - 1)
        {
            allConfigs += "\n";
        }
    }
    
    llRegionSayTo(training_user, 0, allConfigs);
    llRegionSayTo(training_user, 0, "📝 Paste into [WPP]WaypointConfig notecard");
    
    training_user = NULL_KEY;
    found_waypoints = [];
    waypoint_configs = [];
}

cancelTraining()
{
    clearListeners();
    llSetTimerEvent(0.0);
    
    if (training_user != NULL_KEY)
    {
        llRegionSayTo(training_user, 0, "❌ Training cancelled.");
    }
    
    training_state = "IDLE";
    training_user = NULL_KEY;
    training_user_name = "";
    found_waypoints = [];
    waypoint_configs = [];
    current_waypoint_index = 0;
    waypoint_number_offset = 0;
    existing_waypoint_count = 0;
    resetCurrentWaypoint();
}

// ============================================================================
// MAIN STATE MACHINE
// ============================================================================

default
{
    state_entry()
    {
        llOwnerSay("Rose Training Wizard ready");
        
        // Read configuration from RoseConfig if available
        if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD)
        {
            config_notecard_being_read = "RoseConfig";
            notecardLine = 0;
            notecardQuery = llGetNotecardLine("RoseConfig", notecardLine);
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
                    integer equals = llSubStringIndex(data, "=");
                    if (equals != -1)
                    {
                        string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                        string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                        
                        if (config_notecard_being_read == "RoseConfig")
                        {
                            if (configKey == "WAYPOINT_PREFIX")
                            {
                                WAYPOINT_PREFIX = value;
                                llOwnerSay("✅ WAYPOINT_PREFIX: " + WAYPOINT_PREFIX);
                            }
                            else if (configKey == "OWNER_UUID" || llSubStringIndex(configKey, "OWNER_UUID_") == 0)
                            {
                                OWNER_UUIDS += [value];
                            }
                            else if (configKey == "RECEPTIONIST_NAME")
                            {
                                RECEPTIONIST_NAME = value;
                            }
                        }
                        else if (config_notecard_being_read == "[WPP]WaypointConfig")
                        {
                            // Count waypoint entries
                            if (llSubStringIndex(configKey, "WAYPOINT") == 0)
                            {
                                existing_waypoint_count++;
                            }
                        }
                    }
                }
                
                ++notecardLine;
                notecardQuery = llGetNotecardLine(config_notecard_being_read, notecardLine);
            }
            else
            {
                // Finished reading notecard
                if (config_notecard_being_read == "[WPP]WaypointConfig" && training_state == "COUNTING")
                {
                    // Finished counting existing waypoints
                    if (existing_waypoint_count > 0)
                    {
                        llRegionSayTo(training_user, 0, "Found " + (string)existing_waypoint_count + " existing waypoint configurations.");
                        showTrainingModeMenu();
                    }
                    else
                    {
                        // No existing waypoints, proceed directly
                        training_state = "SCANNING";
                        training_mode = "REPLACE";
                        waypoint_number_offset = 0;
                        llOwnerSay("🎓 Training Mode activated by " + training_user_name);
                        llRegionSayTo(training_user, 0, "Starting training mode! Scanning for " + WAYPOINT_PREFIX + " prims...");
                        llSensor("", NULL_KEY, PASSIVE | ACTIVE, SENSOR_RANGE, PI);
                    }
                }
                config_notecard_being_read = "";
            }
        }
    }
    
    sensor(integer num_detected)
    {
        if (training_state != "SCANNING") return;
        
        found_waypoints = [];
        integer i;
        
        for (i = 0; i < num_detected; i++)
        {
            string primName = llDetectedName(i);
            string primNameLower = llToLower(primName);
            string prefixLower = llToLower(WAYPOINT_PREFIX);
            
            if (llSubStringIndex(primNameLower, prefixLower) == 0)
            {
                string remainder = llGetSubString(primName, llStringLength(WAYPOINT_PREFIX), -1);
                remainder = llStringTrim(remainder, STRING_TRIM);
                integer wpNumber = (integer)remainder;
                
                if (wpNumber >= 0 || remainder == "0")
                {
                    key wpKey = llDetectedKey(i);
                    vector wpPos = llDetectedPos(i);
                    
                    found_waypoints += [wpKey, wpNumber, primName, wpPos];
                }
            }
        }
        
        // Sort waypoints
        found_waypoints = sortWaypointsByNumber(found_waypoints);
        
        integer waypointCount = llGetListLength(found_waypoints) / 4;
        
        if (waypointCount == 0)
        {
            llRegionSayTo(training_user, 0, "❌ No " + WAYPOINT_PREFIX + " prims found within " + 
                         (string)((integer)SENSOR_RANGE) + "m. Please add waypoint prims first.");
            cancelTraining();
            return;
        }
        
        llRegionSayTo(training_user, 0, "✓ Found " + (string)waypointCount + " waypoints. Starting configuration...");
        
        // Start with first waypoint
        current_waypoint_index = 0;
        current_wp_number = llList2Integer(found_waypoints, 1);
        showTypeMenu();
    }
    
    no_sensor()
    {
        if (training_state == "SCANNING")
        {
            llRegionSayTo(training_user, 0, "❌ No waypoints found. Make sure " + WAYPOINT_PREFIX + 
                         " prims are within range.");
            cancelTraining();
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (id != training_user) return;
        
        if (training_state == "MODE_SELECT")
        {
            if (message == "Replace All")
            {
                training_mode = "REPLACE";
                waypoint_number_offset = 0;
                training_state = "SCANNING";
                llRegionSayTo(training_user, 0, "Mode: REPLACE ALL - Scanning for " + WAYPOINT_PREFIX + " prims...");
                llSensor("", NULL_KEY, PASSIVE | ACTIVE, SENSOR_RANGE, PI);
            }
            else if (message == "Add New")
            {
                training_mode = "APPEND";
                waypoint_number_offset = existing_waypoint_count;
                training_state = "SCANNING";
                llRegionSayTo(training_user, 0, "Mode: ADD NEW - New waypoints will start at WAYPOINT" + 
                             (string)waypoint_number_offset + ". Scanning for " + WAYPOINT_PREFIX + " prims...");
                llSensor("", NULL_KEY, PASSIVE | ACTIVE, SENSOR_RANGE, PI);
            }
            else if (message == "Cancel")
            {
                llRegionSayTo(training_user, 0, "Training cancelled.");
                cancelTraining();
            }
        }
        else if (training_state == "TYPE")
        {
            if (message == "Transient")
            {
                current_wp_type = "transient";
                // Transient doesn't need duration/animation
                showOrientationMenu();
            }
            else if (message == "Linger")
            {
                current_wp_type = "linger";
                showDurationMenu();
            }
            else if (message == "Sit")
            {
                current_wp_type = "sit";
                showDurationMenu();
            }
        }
        else if (training_state == "DURATION")
        {
            if (message == "15s")
            {
                current_wp_duration = 15;
                showAnimationMenu();
            }
            else if (message == "30s")
            {
                current_wp_duration = 30;
                showAnimationMenu();
            }
            else if (message == "60s")
            {
                current_wp_duration = 60;
                showAnimationMenu();
            }
            else if (message == "120s")
            {
                current_wp_duration = 120;
                showAnimationMenu();
            }
            else if (message == "Custom")
            {
                // For now, default to 30
                current_wp_duration = 30;
                llRegionSayTo(training_user, 0, "⚠️ Custom duration not yet implemented. Using 30s.");
                showAnimationMenu();
            }
            else if (message == "Skip")
            {
                current_wp_duration = 30; // Default
                showAnimationMenu();
            }
        }
        else if (training_state == "ANIMATION")
        {
            if (message != "None")
            {
                current_wp_animation = message;
            }
            showOrientationMenu();
        }
        else if (training_state == "ORIENTATION")
        {
            if (message == "North (90°)")
            {
                current_wp_orientation = 90;
            }
            else if (message == "East (0°)")
            {
                current_wp_orientation = 0;
            }
            else if (message == "South (270°)")
            {
                current_wp_orientation = 270;
            }
            else if (message == "West (180°)")
            {
                current_wp_orientation = 180;
            }
            // None = -1 (already set)
            
            showAttachmentsMenu();
        }
        else if (training_state == "ATTACHMENTS")
        {
            // For now, just finalize
            finalizeWaypoint();
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_TRAINING_START)
        {
            // msg format: "userName"
            // id is the user key
            if (training_state == "IDLE")
            {
                startTraining(id, msg);
            }
            else
            {
                llRegionSayTo(id, 0, "⚠️ Training mode is already active.");
            }
        }
    }
    
    timer()
    {
        // Menu timeout
        if (training_state != "IDLE" && training_state != "COMPLETE")
        {
            llRegionSayTo(training_user, 0, "⏱️ Training session timed out.");
            cancelTraining();
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
