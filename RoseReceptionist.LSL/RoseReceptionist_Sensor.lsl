// RoseReceptionist_Sensor.lsl
// Avatar detection script for Rose Receptionist
// Detects avatars within range and notifies Main script

integer LINK_SENSOR_DETECTED = 1000;
integer LINK_WANDERING_STATE = 2000;

float SENSOR_RANGE = 20.0;
float SENSOR_REPEAT = 5.0;
integer GREETING_TIMEOUT = 1800; // 30 minutes in seconds

list greeted_avatars = []; // [key, timestamp, key, timestamp, ...]
integer greet_enabled = TRUE;

default
{
    state_entry()
    {
        llSensorRepeat("", "", AGENT, SENSOR_RANGE, PI, SENSOR_REPEAT);
        llOwnerSay("Rose Sensor Script active - detecting avatars within " + (string)SENSOR_RANGE + "m");
    }
    
    sensor(integer num_detected)
    {
        if (!greet_enabled) return;
        
        integer i;
        for (i = 0; i < num_detected; i++)
        {
            key avatar_uuid = llDetectedKey(i);
            string avatarName = llDetectedName(i);
            
            // Skip if this is the object owner (Rose herself)
            if (avatar_uuid == llGetOwner()) jump continue;
            
            // Check if we've already greeted this avatar recently
            integer idx = llListFindList(greeted_avatars, [avatar_uuid]);
            if (idx != -1)
            {
                // Check if greeting has timed out
                integer timestamp = llList2Integer(greeted_avatars, idx + 1);
                if (llGetUnixTime() - timestamp < GREETING_TIMEOUT)
                {
                    jump continue; // Still within timeout, don't greet again
                }
                else
                {
                    // Remove old entry
                    greeted_avatars = llDeleteSubList(greeted_avatars, idx, idx + 1);
                }
            }
            
            // New avatar or timeout expired - greet them
            string location = llGetRegionName() + " " + (string)llGetPos();
            string message = (string)avatar_uuid + "|" + avatarName + "|" + location;
            
            llMessageLinked(LINK_SET, LINK_SENSOR_DETECTED, message, NULL_KEY);
            
            // Add to greeted list with current timestamp
            greeted_avatars += [avatar_uuid, llGetUnixTime()];
            
            // Stop wandering when greeting someone
            llMessageLinked(LINK_SET, LINK_WANDERING_STATE, "GREETING", avatar_uuid);
            
            llOwnerSay("Detected: " + avatarName);
            
            @continue;
        }
    }
    
    no_sensor()
    {
        // No avatars detected - could resume wandering
        // This is handled by the wandering script
    }
    
    link_message(integer sender, integer num, string msg, key link_id)
    {
        if (msg == "CLEAR_GREETED")
        {
            // Clear the greeted list (useful for testing or manual reset)
            greeted_avatars = [];
            llOwnerSay("Greeted avatars list cleared");
        }
        else if (msg == "DISABLE_GREET")
        {
            greet_enabled = FALSE;
            llOwnerSay("Avatar greeting disabled");
        }
        else if (msg == "ENABLE_GREET")
        {
            greet_enabled = TRUE;
            llOwnerSay("Avatar greeting enabled");
        }
    }
    
    timer()
    {
        // Periodic cleanup of old greeted avatars
        integer current_time = llGetUnixTime();
        integer i;
        list new_list = [];
        
        for (i = 0; i < llGetListLength(greeted_avatars); i += 2)
        {
            key avatar_uuid = llList2Key(greeted_avatars, i);
            integer timestamp = llList2Integer(greeted_avatars, i + 1);
            
            if (current_time - timestamp < GREETING_TIMEOUT)
            {
                new_list += [avatar_uuid, timestamp];
            }
        }
        
        greeted_avatars = new_list;
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
