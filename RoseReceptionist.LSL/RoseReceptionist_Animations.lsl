// RoseReceptionist_Animations.lsl
// Gesture and animation system for Rose Receptionist
// Triggers animations based on context

integer LINK_ANIMATION = 1003;

// Animation names (these should match animations in inventory)
string ANIM_GREET = "wave";
string ANIM_OFFER = "offer";
string ANIM_THINK = "think";
string ANIM_FLIRT = "flirt";
string ANIM_IDLE = "idle";

// Current animation state
string current_animation = "";
key animation_target = NULL_KEY;

default
{
    state_entry()
    {
        llOwnerSay("Rose Animation Script active");
        
        // Check for required animations in inventory
        checkAnimations();
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_ANIMATION)
        {
            playAnimation(msg);
        }
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }
}

playAnimation(string animation_name)
{
    // Stop current animation if playing
    if (current_animation != "")
    {
        stopCurrentAnimation();
    }
    
    // Map animation names to inventory animations
    string anim_to_play = "";
    
    if (animation_name == "greet")
    {
        anim_to_play = ANIM_GREET;
    }
    else if (animation_name == "offer")
    {
        anim_to_play = ANIM_OFFER;
    }
    else if (animation_name == "think")
    {
        anim_to_play = ANIM_THINK;
    }
    else if (animation_name == "flirt")
    {
        anim_to_play = ANIM_FLIRT;
    }
    else if (animation_name == "idle")
    {
        anim_to_play = ANIM_IDLE;
    }
    else
    {
        // Unknown animation
        return;
    }
    
    // Check if animation exists in inventory
    if (llGetInventoryType(anim_to_play) == INVENTORY_ANIMATION)
    {
        llStartAnimation(anim_to_play);
        current_animation = anim_to_play;
        
        // Set timer to stop animation after a few seconds
        llSetTimerEvent(3.0);
    }
    else
    {
        llOwnerSay("Warning: Animation '" + anim_to_play + "' not found in inventory");
    }
}

stopCurrentAnimation()
{
    if (current_animation != "" && current_animation != ANIM_IDLE)
    {
        llStopAnimation(current_animation);
        current_animation = "";
    }
}

checkAnimations()
{
    // Check for animations and warn if missing
    list required_anims = [ANIM_GREET, ANIM_OFFER, ANIM_THINK, ANIM_FLIRT];
    
    integer i;
    integer missing_count = 0;
    
    for (i = 0; i < llGetListLength(required_anims); i++)
    {
        string anim = llList2String(required_anims, i);
        if (llGetInventoryType(anim) != INVENTORY_ANIMATION)
        {
            llOwnerSay("Missing animation: " + anim);
            missing_count++;
        }
    }
    
    if (missing_count > 0)
    {
        llOwnerSay("Warning: " + (string)missing_count + " animations missing. Rose will work but gestures may not display.");
        llOwnerSay("Recommended animations: wave, offer, think, flirt");
    }
    else
    {
        llOwnerSay("All required animations present!");
    }
}

timer()
{
    // Stop animation after timeout
    stopCurrentAnimation();
    llSetTimerEvent(0.0);
}
