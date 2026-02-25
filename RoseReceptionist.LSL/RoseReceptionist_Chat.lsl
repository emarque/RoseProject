// RoseReceptionist_Chat.lsl
// Conversation handler for Rose Receptionist
// Listens for chat messages and sends responses

integer LINK_CHAT_MESSAGE = 1001;
integer LINK_SPEAK = 1002;
integer LINK_WANDERING_STATE = 2000;

// Schedule info link messages (for schedule-aware chat)
integer LINK_GET_SCHEDULE_INFO = 5000;
integer LINK_SCHEDULE_INFO = 5001;

integer CHAT_CHANNEL = 0;
float LISTEN_RANGE = 20.0;
integer listen_handle = -1;

string RECEPTIONIST_NAME = "Rose";

// Schedule period state (updated via link messages)
string current_period = "WORK";
integer period_at_work = TRUE;
integer period_is_awake = TRUE;
integer sleep_mention_threshold = 3;

// Mention tracking for sleep mode (NIGHT period)
list mention_counts = []; // [avatar_key, count, timestamp, ...]
integer MENTION_TIMEOUT = 300; // 5 minutes - reset count if no mentions

// Transcript delimiters for communication with backend
string TRANSCRIPT_START = "[TRANSCRIPT]";
string TRANSCRIPT_END = "[/TRANSCRIPT]";

// Session tracking
list active_sessions = []; // [avatarKey, sessionId, timestamp, ...]
integer SESSION_TIMEOUT = 1800; // 30 minutes

// Conversation state
key current_speaker = NULL_KEY;
integer waiting_for_response = FALSE;

// Conversation tracking for transcript mode
list conversation_participants = []; // List of avatar keys in current conversation
list conversation_transcript = []; // [speaker_name, message, speaker_name, message, ...]
integer MAX_TRANSCRIPT_MESSAGES = 10; // Keep last 10 messages (stored as 20 list elements: speaker+message pairs)
integer CONVERSATION_TIMEOUT = 60; // 60 seconds of silence ends conversation
integer last_message_time = 0;

// Schedule-aware chat helper functions
requestScheduleInfo()
{
    // Request current schedule period info from WPManager
    llMessageLinked(LINK_SET, LINK_GET_SCHEDULE_INFO, "", NULL_KEY);
}

integer incrementMentionCount(key avatar_key, integer is_shout)
{
    // Clean up old mentions (older than MENTION_TIMEOUT)
    integer now = llGetUnixTime();
    integer i;
    for (i = llGetListLength(mention_counts) - 3; i >= 0; i -= 3)
    {
        integer timestamp = llList2Integer(mention_counts, i + 2);
        if (now - timestamp > MENTION_TIMEOUT)
        {
            mention_counts = llDeleteSubList(mention_counts, i, i + 2);
        }
    }
    
    // Find existing entry or add new one
    integer idx = llListFindList(mention_counts, [avatar_key]);
    integer count = 1;
    
    if (idx != -1)
    {
        count = llList2Integer(mention_counts, idx + 1) + 1;
        mention_counts = llListReplaceList(mention_counts, [count, now], idx + 1, idx + 2);
    }
    else
    {
        mention_counts += [avatar_key, count, now];
    }
    
    // Shouts count as meeting threshold immediately
    if (is_shout)
    {
        return sleep_mention_threshold;
    }
    
    return count;
}

resetMentionCount(key avatar_key)
{
    integer idx = llListFindList(mention_counts, [avatar_key]);
    if (idx != -1)
    {
        mention_counts = llDeleteSubList(mention_counts, idx, idx + 2);
    }
}

// Check if a message is directed at Rose
integer isMessageForRose(string message, key speaker_id)
{
    string msg_lower = llToLower(message);
    string name_lower = llToLower(RECEPTIONIST_NAME);
    
    // Message contains Rose's name
    if (llSubStringIndex(msg_lower, name_lower) != -1)
    {
        return TRUE;
    }
    
    // Currently in active conversation with this speaker
    if (llListFindList(conversation_participants, [speaker_id]) != -1)
    {
        return TRUE;
    }
    
    return FALSE;
}

// Build transcript string from conversation history
string buildTranscriptString()
{
    if (llGetListLength(conversation_transcript) == 0)
    {
        return "";
    }
    
    string transcript = TRANSCRIPT_START + "\n";
    integer i;
    integer len = llGetListLength(conversation_transcript);
    
    for (i = 0; i < len; i += 2)
    {
        string speaker = llList2String(conversation_transcript, i);
        string message = llList2String(conversation_transcript, i + 1);
        transcript += speaker + ": " + message + "\n";
    }
    
    transcript += TRANSCRIPT_END;
    return transcript;
}

// Add message to conversation transcript
addToTranscript(string speaker_name, string message)
{
    conversation_transcript += [speaker_name, message];
    
    // Keep only last MAX_TRANSCRIPT_MESSAGES messages
    integer len = llGetListLength(conversation_transcript);
    if (len > MAX_TRANSCRIPT_MESSAGES * 2)
    {
        integer to_remove = len - (MAX_TRANSCRIPT_MESSAGES * 2);
        conversation_transcript = llDeleteSubList(conversation_transcript, 0, to_remove - 1);
    }
}

string getOrCreateSession(key avatar_uuid)
{
    // Look for existing session
    integer idx = llListFindList(active_sessions, [avatar_uuid]);
    
    if (idx != -1)
    {
        // Update timestamp
        active_sessions = llListReplaceList(active_sessions, [llGetUnixTime()], idx + 2, idx + 2);
        return llList2String(active_sessions, idx + 1);
    }
    
    // Create new session
    string sessionId = (string)llGenerateKey();
    active_sessions += [avatar_uuid, sessionId, llGetUnixTime()];
    
    return sessionId;
}

default
{
    state_entry()
    {
        // Start listening on public chat
        listen_handle = llListen(CHAT_CHANNEL, "", NULL_KEY, "");
        llOwnerSay("Rose Chat Script active - listening on channel " + (string)CHAT_CHANNEL);
        
        // Request initial schedule info
        requestScheduleInfo();
        
        // Start timer for session cleanup
        llSetTimerEvent(300.0); // Check every 5 minutes
    }
    
    listen(integer channel, string name, key link_id, string message)
    {
        // Ignore messages from self
        if (link_id == llGetKey()) return;
        
        // Check if message is directed at Rose using smart detection
        if (!isMessageForRose(message, link_id))
        {
            return;
        }
        
        // Request current schedule info before processing
        requestScheduleInfo();
        
        // Check if shouted (for sleep mode threshold)
        integer is_shout = FALSE;
        if (llGetSubString(message, -1, -1) == "!")
        {
            is_shout = TRUE;
        }
        
        // Handle sleep mode (NIGHT period when not awake)
        if (!period_is_awake)
        {
            integer mention_count = incrementMentionCount(link_id, is_shout);
            if (mention_count < sleep_mention_threshold)
            {
                // Not enough mentions yet, ignore
                return;
            }
            // Enough mentions - respond with sleepy confusion
            llMessageLinked(LINK_SET, LINK_SPEAK, "huh? sorry, it's late, can this wait until tomorrow?", NULL_KEY);
            resetMentionCount(link_id);
            return;
        }
        
        // Handle off-work mode (not at work but awake)
        if (!period_at_work)
        {
            // Check if message seems work-related (simple keyword check)
            string msg_lower = llToLower(message);
            if (llSubStringIndex(msg_lower, "work") != -1 ||
                llSubStringIndex(msg_lower, "job") != -1 ||
                llSubStringIndex(msg_lower, "shift") != -1 ||
                llSubStringIndex(msg_lower, "task") != -1 ||
                llSubStringIndex(msg_lower, "report") != -1 ||
                llSubStringIndex(msg_lower, "meeting") != -1)
            {
                // Work-related during off-hours
                llMessageLinked(LINK_SET, LINK_SPEAK, "Sorry, I'm off the clock, can we chat about this tomorrow?", NULL_KEY);
                return;
            }
            // Non-work chat is fine, continue normal processing
        }
        
        // Add speaker to conversation participants if not already there
        if (llListFindList(conversation_participants, [link_id]) == -1)
        {
            conversation_participants += [link_id];
        }
        
        // Get or create session ID for this avatar
        string sessionId = getOrCreateSession(link_id);
        
        // Extract the actual message (remove name if present)
        string clean_message = message;
        string msg_lower = llToLower(message);
        string name_lower = llToLower(RECEPTIONIST_NAME);
        
        if (llSubStringIndex(msg_lower, name_lower) != -1)
        {
            // Try to remove the name from the message
            integer name_start = llSubStringIndex(msg_lower, name_lower);
            if (name_start == 0)
            {
                // Name at start
                clean_message = llStringTrim(
                    llGetSubString(message, llStringLength(RECEPTIONIST_NAME), -1),
                    STRING_TRIM);
                
                // Remove leading punctuation
                if (llGetSubString(clean_message, 0, 0) == "," ||
                    llGetSubString(clean_message, 0, 0) == ":" ||
                    llGetSubString(clean_message, 0, 0) == "-")
                {
                    clean_message = llStringTrim(llGetSubString(clean_message, 1, -1), STRING_TRIM);
                }
            }
        }
        
        // Add user message to transcript
        addToTranscript(name, clean_message);
        last_message_time = llGetUnixTime();
        
        // Build transcript string
        string transcript = buildTranscriptString();
        
        // Send to backend via Main script
        // Format: avatarKey|avatarName|message|sessionId|transcript
        string payload = (string)link_id + "|" + name + "|" + clean_message + "|" + sessionId + "|" + transcript;
        llMessageLinked(LINK_SET, LINK_CHAT_MESSAGE, payload, NULL_KEY);
        
        current_speaker = link_id;
        waiting_for_response = TRUE;
        
        // Notify wandering script to pause
        llMessageLinked(LINK_SET, LINK_WANDERING_STATE, "CHATTING", link_id);
        
        // Set timer for conversation timeout
        llSetTimerEvent(1.0); // Check every second
    }
    
    link_message(integer sender, integer num, string msg, key link_id)
    {
        if (num == LINK_SPEAK)
        {
            // Add Rose's response to transcript
            addToTranscript(RECEPTIONIST_NAME, msg);
            
            // Speak the response
            llSay(CHAT_CHANNEL, msg);
            waiting_for_response = FALSE;
            
            // Update last message time
            last_message_time = llGetUnixTime();
        }
        else if (num == LINK_SCHEDULE_INFO)
        {
            // Parse schedule info: "PERIOD|at_work|is_awake|threshold"
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) >= 4)
            {
                current_period = llList2String(parts, 0);
                period_at_work = llList2Integer(parts, 1);
                period_is_awake = llList2Integer(parts, 2);
                sleep_mention_threshold = llList2Integer(parts, 3);
            }
        }
    }
    
    timer()
    {
        integer current_time = llGetUnixTime();
        
        // Check for conversation timeout (60 seconds of silence)
        if (last_message_time > 0 && (current_time - last_message_time) >= CONVERSATION_TIMEOUT)
        {
            // End conversation - clear transcript and participants
            if (llGetListLength(conversation_transcript) > 0)
            {
                conversation_transcript = [];
                conversation_participants = [];
                current_speaker = NULL_KEY;
                waiting_for_response = FALSE;
                last_message_time = 0;
                
                // Resume wandering
                llMessageLinked(LINK_SET, LINK_WANDERING_STATE, "IDLE", NULL_KEY);
                
                // Slow down timer to session cleanup rate
                llSetTimerEvent(300.0);
            }
        }
        
        // Clean up old sessions
        list new_sessions = [];
        
        integer i;
        for (i = 0; i < llGetListLength(active_sessions); i += 3)
        {
            key avatar_uuid = llList2Key(active_sessions, i);
            string sessionId = llList2String(active_sessions, i + 1);
            integer timestamp = llList2Integer(active_sessions, i + 2);
            
            if (current_time - timestamp < SESSION_TIMEOUT)
            {
                new_sessions += [avatar_uuid, sessionId, timestamp];
            }
        }
        
        active_sessions = new_sessions;
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
