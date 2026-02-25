// [WPP]WPNavigator.lsl
// Navigation Engine - Handles actual movement via keyframed motion

// Debug mode
integer DEBUG = FALSE;  // Will be loaded from RoseConfig.txt if needed

// Debug output function
debugSay(string msg)
{
    if (DEBUG)
    {
        llOwnerSay("[Navigator] " + msg);
    }
}

// CONFIGURATION
float MOVEMENT_SPEED = 1.5;  // meters per second
integer NAVIGATION_TIMEOUT = 60; // seconds
float WAYPOINT_POSITION_TOLERANCE = .0125; // meters

// Link messages - Communication with Manager script
integer LINK_NAV_GOTO = 4000;      // Manager->Navigator: Go to position (key=wpKey, msg=position)
integer LINK_NAV_ARRIVED = 4001;   // Navigator->Manager: Arrived at waypoint
integer LINK_NAV_TIMEOUT = 4002;   // Navigator->Manager: Navigation timeout
integer LINK_WANDERING_STATE = 2000; // From other scripts (greeting/chatting)

// STATE VARIABLES
key current_target_key = NULL_KEY;
vector current_target_pos = ZERO_VECTOR;
integer navigation_start_time = 0;
integer is_navigating = FALSE;
string current_state = "IDLE";

// Walk animation state
string current_walk_animation = "";
list available_walk_animations = [];
string default_walk = "anim walk";

// Animation scanning
scanInventoryAnimations()
{
    available_walk_animations = [];
    
    integer count = llGetInventoryNumber(INVENTORY_ANIMATION);
    integer i;
    for (i = 0; i < count; i++)
    {
        string name = llGetInventoryName(INVENTORY_ANIMATION, i);
        
        // Check if animation starts with "anim "
        if (llSubStringIndex(name, "anim ") == 0)
        {
            string remainder = llGetSubString(name, 5, -1);
            integer spacePos = llSubStringIndex(remainder, " ");
            
            if (spacePos != -1)
            {
                string category = llGetSubString(remainder, 0, spacePos - 1);
                
                if (category == "walk")
                {
                    available_walk_animations += [name];
                }
            }
        }
    }
}

// Start a random walk animation
startWalkAnimation()
{
    // Stop any current walk animation first
    stopWalkAnimation();
    
    integer numAnims = llGetListLength(available_walk_animations);
    string walk_anim;
    
    if (numAnims > 0)
    {
        integer randIndex = (integer)llFrand(numAnims);
        walk_anim = llList2String(available_walk_animations, randIndex);
    }
    else
    {
        walk_anim = default_walk;
    }
    
    // Send link message to Animation script to play the animation
    llMessageLinked(LINK_SET, 0, "PLAY_ANIM:" + walk_anim, NULL_KEY);
    current_walk_animation = walk_anim;
}

// Stop the current walk animation
stopWalkAnimation()
{
    if (current_walk_animation != "")
    {
        // Send link message to Animation script to stop the animation
        llMessageLinked(LINK_SET, 0, "STOP_ANIM:" + current_walk_animation, NULL_KEY);
        current_walk_animation = "";
    }
}

// Navigate to target position
navigateToTarget(vector target_pos, key target_key)
{
    current_target_pos = target_pos;
    current_target_key = target_key;
    
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
    
    // Calculate and set rotation to face direction of travel
    float fDistance = llVecDist(<current_target_pos.x, current_target_pos.y, 0>, <start_pos.x, start_pos.y, 0>);
    llSetRot(llRotBetween(<1,0,0>, llVecNorm(<fDistance, 0, current_target_pos.z - start_pos.z>)) * llRotBetween(<1,0,0>, llVecNorm(<current_target_pos.x - start_pos.x, current_target_pos.y - start_pos.y, 0>)));
    
    // Start a random walk animation before navigating
    startWalkAnimation();
    
    // Use keyframed motion to move to waypoint
    llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
    
    // Set up the motion
    llSetKeyframedMotion([offset, time_to_travel], 
                         [KFM_MODE, KFM_FORWARD, KFM_DATA, KFM_TRANSLATION]);
    
    // Start the motion
    llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_PLAY]);
    
    is_navigating = TRUE;
    navigation_start_time = llGetUnixTime();
    current_state = "WALKING";
    llSetTimerEvent(1.0);  // Check progress every second
}

// Stop navigation
stopNavigation()
{
    if (is_navigating)
    {
        llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
        stopWalkAnimation();
        is_navigating = FALSE;
        current_state = "IDLE";
        llSetTimerEvent(0.0);
    }
}

// MAIN STATE MACHINE
default
{
    state_entry()
    {
        // Enable physics for keyframed motion
        llSetStatus(STATUS_PHYSICS, FALSE);
        
        // Scan for walk animations
        scanInventoryAnimations();
        
        debugSay("Navigator ready");
    }
    
    timer()
    {
        if (current_state == "WALKING")
        {
            // Check for navigation timeout
            if (llGetUnixTime() - navigation_start_time > NAVIGATION_TIMEOUT)
            {
                // Stop keyframed motion
                llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
                stopWalkAnimation();
                is_navigating = FALSE;
                
                // Notify manager of timeout
                llMessageLinked(LINK_SET, LINK_NAV_TIMEOUT, "", current_target_key);
                
                current_state = "IDLE";
                llSetTimerEvent(0.0);
            }
            
            // Check if we've reached the target
            vector current_pos = llGetPos();
            float distance = llVecDist(current_pos, current_target_pos);
            
            if (distance < WAYPOINT_POSITION_TOLERANCE)
            {
                // Reached waypoint
                llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
                stopWalkAnimation();
                is_navigating = FALSE;
                current_state = "IDLE";
                llSetTimerEvent(0.0);
                
                // Notify manager that we arrived
                llMessageLinked(LINK_SET, LINK_NAV_ARRIVED, (string)current_target_pos, current_target_key);
            }
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_NAV_GOTO)
        {
            // Manager wants us to navigate to a position
            // msg contains the position as string, id contains waypoint key
            vector target = (vector)msg;
            navigateToTarget(target, id);
        }
        else if (num == LINK_WANDERING_STATE)
        {
            if (msg == "GREETING" || msg == "CHATTING")
            {
                // Stop wandering during interaction
                if (is_navigating)
                {
                    stopNavigation();
                }
            }
            else if (msg == "DONE")
            {
                // Interaction done, could resume if needed
                // Manager will decide what to do next
            }
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            // Rescan animations when inventory changes
            scanInventoryAnimations();
        }
    }
}
