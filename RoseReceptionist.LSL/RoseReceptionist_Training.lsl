// RoseReceptionist_Training.lsl
// Tap-to-Train Waypoint Configuration System for Rose Receptionist
// User taps Rose at each location to configure waypoints

// ============================================================================
// CONFIGURATION
// ============================================================================

string WAYPOINT_PREFIX = "Waypoint";

// Link messages
integer LINK_TRAINING_START = 3000;
integer LINK_TRAINING_COMPLETE = 3001;

// ============================================================================
// STATE VARIABLES
// ============================================================================

// Training state machine
string training_state = "IDLE"; // IDLE, ACTIVE, TYPE, NAME_INPUT, DURATION, DIRECTION, ANIMATION, ATTACHABLES, COMPLETE
integer training_active = FALSE;
integer waypoint_counter = 0;
key training_user = NULL_KEY;
string training_user_name = "";
vector current_tap_position = ZERO_VECTOR;

// Waypoint being configured
string wp_type = "";
string wp_name = "";
integer wp_duration = 0;
integer wp_orientation = -1;
string wp_animation = "";
list wp_attachments = [];

// Authorization
list OWNER_UUIDS = [];
string RECEPTIONIST_NAME = "Rose";

// Available animations and attachables from RoseConfig
list available_animations = [];
list available_attachables = [];
string current_section = "";

// Dialog channels and listeners
integer dialog_channel = 0;
integer dialog_listener = 0;
integer textbox_channel = 0;
integer textbox_listener = 0;

// Notecard reading for config
key notecardQuery;
integer notecardLine = 0;

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

// Reset waypoint data
resetWaypointData()
{
    wp_type = "";
    wp_name = "";
    wp_duration = 0;
    wp_orientation = -1;
    wp_animation = "";
    wp_attachments = [];
    current_tap_position = ZERO_VECTOR;
}

// Generate JSON for current waypoint
string generateWaypointJSON()
{
    string json = "{\"type\":\"" + wp_type + "\"";
    
    // Add name
    if (wp_name == "")
    {
        wp_name = "waypoint " + (string)waypoint_counter;
    }
    json += ",\"name\":\"" + wp_name + "\"";
    
    // Add orientation if set (for linger type)
    if (wp_orientation != -1)
    {
        json += ",\"orientation\":" + (string)wp_orientation;
    }
    
    // Add time if linger or sit
    if ((wp_type == "linger" || wp_type == "sit") && wp_duration > 0)
    {
        json += ",\"time\":" + (string)wp_duration;
    }
    
    // Add animation if set
    if (wp_animation != "")
    {
        json += ",\"animation\":\"" + wp_animation + "\"";
    }
    
    // Add attachments if any
    json += ",\"attachments\":[";
    integer i;
    integer attachCount = llGetListLength(wp_attachments);
    for (i = 0; i < attachCount; i += 2)
    {
        if (i > 0) json += ",";
        string item = llList2String(wp_attachments, i);
        string point = llList2String(wp_attachments, i + 1);
        json += "{\"item\":\"" + item + "\",\"point\":\"" + point + "\"}";
    }
    json += "]";
    
    json += "}";
    return json;
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
    training_active = TRUE;
    waypoint_counter = 0;
    training_state = "ACTIVE";
    
    llOwnerSay("🎓 Training Mode activated by " + userName);
    llRegionSayTo(user, 0, "Tap me at each waypoint location to configure");
    llSetTimerEvent(300.0); // 5-minute timeout
}

showWaypointTypeMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "📍 Waypoint " + (string)waypoint_counter + 
                     "\n\nWhat type of waypoint is this?";
    
    llDialog(training_user, message,
        ["Transient", "Linger", "Sit", "Done Training"],
        dialog_channel);
    
    training_state = "TYPE";
    llSetTimerEvent(60.0); // Menu timeout
}

showNameInput()
{
    clearListeners();
    
    textbox_channel = -1000 - (integer)llFrand(9999);
    textbox_listener = llListen(textbox_channel, "", training_user, "");
    
    string message;
    if (wp_type == "transient")
    {
        message = "Enter location name (e.g., 'hallway'):";
    }
    else
    {
        message = "Enter activity name:";
    }
    
    llTextBox(training_user, message, textbox_channel);
    training_state = "NAME_INPUT";
    llSetTimerEvent(60.0);
}

showDurationMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "⏱️ Waypoint " + (string)waypoint_counter + 
                     "\n\nHow long should I stay here?";
    
    llDialog(training_user, message,
        ["15s", "30s", "60s", "120s", "Custom"],
        dialog_channel);
    
    training_state = "DURATION";
    llSetTimerEvent(60.0);
}

showDirectionMenu()
{
    clearListeners();
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "🧭 Waypoint " + (string)waypoint_counter + 
                     "\n\nWhich direction should I face?";
    
    llDialog(training_user, message,
        ["North", "East", "South", "West", "None"],
        dialog_channel);
    
    training_state = "DIRECTION";
    llSetTimerEvent(60.0);
}

showAnimationMenu()
{
    clearListeners();
    
    if (llGetListLength(available_animations) == 0)
    {
        // Skip animation selection
        wp_animation = "";
        if (wp_type == "sit")
        {
            outputWaypointConfig();
        }
        else
        {
            showAttachablesMenu();
        }
        return;
    }
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "🎭 Waypoint " + (string)waypoint_counter + 
                     "\n\nSelect animation:";
    
    list buttons = available_animations + ["None"];
    llDialog(training_user, message, buttons, dialog_channel);
    
    training_state = "ANIMATION";
    llSetTimerEvent(60.0);
}

showAttachablesMenu()
{
    clearListeners();
    
    if (llGetListLength(available_attachables) == 0)
    {
        // Skip attachables, output waypoint
        outputWaypointConfig();
        return;
    }
    
    dialog_channel = -1000 - (integer)llFrand(9999);
    dialog_listener = llListen(dialog_channel, "", training_user, "");
    
    string message = "📎 Waypoint " + (string)waypoint_counter + 
                     "\n\nSelect attachables (or Done):";
    
    list buttons = available_attachables + ["None", "Done"];
    llDialog(training_user, message, buttons, dialog_channel);
    
    training_state = "ATTACHABLES";
    llSetTimerEvent(60.0);
}

outputWaypointConfig()
{
    string json = generateWaypointJSON();
    string output = "WAYPOINT" + (string)waypoint_counter + "=" + (string)current_tap_position + "|" + json;
    
    llOwnerSay(output);
    
    waypoint_counter++;
    resetWaypointData();
    training_state = "ACTIVE";
    llRegionSayTo(training_user, 0, "✓ Waypoint " + (string)(waypoint_counter - 1) + " configured. Tap me at next location or say 'done'.");
    llSetTimerEvent(300.0); // Back to 5-minute timeout
}

completeTraining()
{
    training_state = "COMPLETE";
    training_active = FALSE;
    clearListeners();
    llSetTimerEvent(0.0);
    
    llRegionSayTo(training_user, 0, "✅ Training complete! " + (string)waypoint_counter + " waypoints configured.");
    llOwnerSay("📝 Training complete. Copy config above and paste into [WPP]WaypointConfig notecard");
    
    training_user = NULL_KEY;
    training_user_name = "";
    waypoint_counter = 0;
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
    training_active = FALSE;
    training_user = NULL_KEY;
    training_user_name = "";
    waypoint_counter = 0;
    resetWaypointData();
}

// ============================================================================
// MAIN STATE MACHINE
// ============================================================================

default
{
    state_entry()
    {
        llOwnerSay("Rose Tap-to-Train Wizard ready");
        
        // Read configuration from RoseConfig if available
        if (llGetInventoryType("RoseConfig") == INVENTORY_NOTECARD)
        {
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
                
                // Check for section headers
                if (data == "[AvailableAnimations]")
                {
                    current_section = "animations";
                }
                else if (data == "[AvailableAttachables]")
                {
                    current_section = "attachables";
                }
                // Skip empty lines and comments
                else if (data != "" && llGetSubString(data, 0, 0) != "#")
                {
                    // If we're in a section, add to appropriate list
                    if (current_section == "animations" && llSubStringIndex(data, "=") == -1)
                    {
                        available_animations += [data];
                    }
                    else if (current_section == "attachables" && llSubStringIndex(data, "=") == -1)
                    {
                        available_attachables += [data];
                    }
                    else
                    {
                        // Parse KEY=VALUE (resets current_section)
                        integer equals = llSubStringIndex(data, "=");
                        if (equals != -1)
                        {
                            current_section = "";
                            string configKey = llStringTrim(llGetSubString(data, 0, equals - 1), STRING_TRIM);
                            string value = llStringTrim(llGetSubString(data, equals + 1, -1), STRING_TRIM);
                            
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
                    }
                }
                
                ++notecardLine;
                notecardQuery = llGetNotecardLine("RoseConfig", notecardLine);
            }
            else
            {
                // Finished reading notecard
                if (llGetListLength(available_animations) > 0)
                {
                    llOwnerSay("✅ Loaded " + (string)llGetListLength(available_animations) + " animations");
                }
                if (llGetListLength(available_attachables) > 0)
                {
                    llOwnerSay("✅ Loaded " + (string)llGetListLength(available_attachables) + " attachables");
                }
            }
        }
    }
    
    touch_start(integer num_detected)
    {
        key toucher = llDetectedKey(0);
        
        if (training_active && toucher == training_user && training_state == "ACTIVE")
        {
            // Capture position of Rose (not toucher)
            current_tap_position = llGetPos();
            
            // Show waypoint type menu
            showWaypointTypeMenu();
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (id != training_user) return;
        
        if (channel == dialog_channel)
        {
            if (training_state == "TYPE")
            {
                if (message == "Transient")
                {
                    wp_type = "transient";
                    showNameInput();
                }
                else if (message == "Linger")
                {
                    wp_type = "linger";
                    showNameInput();
                }
                else if (message == "Sit")
                {
                    wp_type = "sit";
                    showNameInput();
                }
                else if (message == "Done Training")
                {
                    completeTraining();
                }
            }
            else if (training_state == "DURATION")
            {
                if (message == "15s")
                {
                    wp_duration = 15;
                    if (wp_type == "linger")
                    {
                        showDirectionMenu();
                    }
                    else
                    {
                        showAnimationMenu();
                    }
                }
                else if (message == "30s")
                {
                    wp_duration = 30;
                    if (wp_type == "linger")
                    {
                        showDirectionMenu();
                    }
                    else
                    {
                        showAnimationMenu();
                    }
                }
                else if (message == "60s")
                {
                    wp_duration = 60;
                    if (wp_type == "linger")
                    {
                        showDirectionMenu();
                    }
                    else
                    {
                        showAnimationMenu();
                    }
                }
                else if (message == "120s")
                {
                    wp_duration = 120;
                    if (wp_type == "linger")
                    {
                        showDirectionMenu();
                    }
                    else
                    {
                        showAnimationMenu();
                    }
                }
                else if (message == "Custom")
                {
                    // For now, default to 30
                    wp_duration = 30;
                    llRegionSayTo(training_user, 0, "⚠️ Custom duration not yet implemented. Using 30s.");
                    if (wp_type == "linger")
                    {
                        showDirectionMenu();
                    }
                    else
                    {
                        showAnimationMenu();
                    }
                }
            }
            else if (training_state == "DIRECTION")
            {
                if (message == "North")
                {
                    wp_orientation = 90;
                }
                else if (message == "East")
                {
                    wp_orientation = 0;
                }
                else if (message == "South")
                {
                    wp_orientation = 270;
                }
                else if (message == "West")
                {
                    wp_orientation = 180;
                }
                // None = -1 (default)
                
                showAnimationMenu();
            }
            else if (training_state == "ANIMATION")
            {
                if (message != "None")
                {
                    wp_animation = message;
                }
                
                if (wp_type == "sit")
                {
                    outputWaypointConfig();
                }
                else
                {
                    showAttachablesMenu();
                }
            }
            else if (training_state == "ATTACHABLES")
            {
                if (message == "Done")
                {
                    outputWaypointConfig();
                }
                else if (message != "None")
                {
                    // Add attachable with default attachment point (RightHand)
                    wp_attachments += [message, "RightHand"];
                    // Show menu again for multiple selections
                    showAttachablesMenu();
                }
                else
                {
                    // None selected, proceed to output
                    outputWaypointConfig();
                }
            }
        }
        else if (channel == textbox_channel)
        {
            if (training_state == "NAME_INPUT")
            {
                wp_name = message;
                
                if (wp_type == "transient")
                {
                    // Transient: just output immediately
                    outputWaypointConfig();
                }
                else
                {
                    // Linger or Sit: show duration menu
                    showDurationMenu();
                }
            }
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_TRAINING_START)
        {
            // msg format: "userName"
            // id is the user key
            if (training_state == "IDLE" || training_state == "COMPLETE")
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
        // Menu/training timeout
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
