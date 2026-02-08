// RoseReceptionist_GoWander3.lsl
// Wandering system for Rose Receptionist
// Makes Rose move around naturally within defined boundaries

integer LINK_WANDERING_STATE = 2000;

// Configuration
float WANDER_RADIUS = 10.0;
vector HOME_POSITION;
integer WANDER_ENABLED = TRUE;

// State
string wander_state = "IDLE";
float idle_time_min = 30.0;
float idle_time_max = 120.0;
float walk_speed = 0.5;
integer return_home_interval = 600; // 10 minutes
integer last_home_return = 0;

// Navigation
vector current_target = ZERO_VECTOR;
integer is_navigating = FALSE;

default
{
    state_entry()
    {
        HOME_POSITION = llGetPos();
        last_home_return = llGetUnixTime();
        
        llOwnerSay("Rose Wandering Script active");
        llOwnerSay("Home position: " + (string)HOME_POSITION);
        llOwnerSay("Wander radius: " + (string)WANDER_RADIUS + "m");
        
        if (WANDER_ENABLED)
        {
            setState("IDLE");
        }
    }
    
    timer()
    {
        if (!WANDER_ENABLED) return;
        
        if (wander_state == "IDLE")
        {
            // Check if it's time to return home
            if (llGetUnixTime() - last_home_return > return_home_interval)
            {
                returnHome();
            }
            else
            {
                // Wander to a random point
                wanderToRandomPoint();
            }
        }
        else if (wander_state == "WALKING")
        {
            // Check if we've reached the target
            vector current_pos = llGetPos();
            float distance = llVecDist(current_pos, current_target);
            
            if (distance < 0.5)
            {
                // Reached target, go idle
                setState("IDLE");
            }
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_WANDERING_STATE)
        {
            if (msg == "GREETING" || msg == "CHATTING")
            {
                // Stop wandering during interaction
                setState("INTERACTING");
                
                // Cancel any current navigation
                if (is_navigating)
                {
                    llNavigateTo(llGetPos(), []);
                    is_navigating = FALSE;
                }
            }
            else if (msg == "IDLE" || msg == "RESUME")
            {
                // Resume wandering
                setState("IDLE");
            }
        }
        else if (msg == "SET_HOME")
        {
            // Set new home position
            HOME_POSITION = llGetPos();
            last_home_return = llGetUnixTime();
            llOwnerSay("Home position updated: " + (string)HOME_POSITION);
        }
        else if (msg == "TOGGLE_WANDER")
        {
            WANDER_ENABLED = !WANDER_ENABLED;
            llOwnerSay("Wandering " + (string)(WANDER_ENABLED ? "enabled" : "disabled"));
            
            if (!WANDER_ENABLED)
            {
                setState("IDLE");
                llSetTimerEvent(0.0);
            }
            else
            {
                setState("IDLE");
            }
        }
    }
    
    moving_end()
    {
        // Navigation completed
        is_navigating = FALSE;
        
        if (wander_state == "WALKING")
        {
            setState("IDLE");
        }
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }
}

setState(string new_state)
{
    wander_state = new_state;
    
    if (new_state == "IDLE")
    {
        // Set timer for next action
        float idle_duration = llFrand(idle_time_max - idle_time_min) + idle_time_min;
        llSetTimerEvent(idle_duration);
    }
    else if (new_state == "INTERACTING")
    {
        // Stop timer during interaction
        llSetTimerEvent(0.0);
    }
}

wanderToRandomPoint()
{
    // Calculate random point within wander radius
    float angle = llFrand(TWO_PI);
    float distance = llFrand(WANDER_RADIUS);
    
    vector offset = <llCos(angle) * distance, llSin(angle) * distance, 0.0>;
    vector target = HOME_POSITION + offset;
    
    // Check if target is within parcel and not blocked
    current_target = target;
    
    // Start navigation
    list options = [
        FORCE_DIRECT_PATH, FALSE,
        CHARACTER_TYPE, CHARACTER_TYPE_A,
        CHARACTER_MAX_SPEED, walk_speed
    ];
    
    llNavigateTo(current_target, options);
    is_navigating = TRUE;
    
    setState("WALKING");
}

returnHome()
{
    current_target = HOME_POSITION;
    last_home_return = llGetUnixTime();
    
    list options = [
        FORCE_DIRECT_PATH, FALSE,
        CHARACTER_TYPE, CHARACTER_TYPE_A,
        CHARACTER_MAX_SPEED, walk_speed
    ];
    
    llNavigateTo(current_target, options);
    is_navigating = TRUE;
    
    setState("WALKING");
}
