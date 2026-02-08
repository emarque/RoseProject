// RoseReceptionist_Chat.lsl
// Conversation handler for Rose Receptionist
// Listens for chat messages and sends responses

integer LINK_CHAT_MESSAGE = 1001;
integer LINK_SPEAK = 1002;
integer LINK_WANDERING_STATE = 2000;

integer CHAT_CHANNEL = 0;
float LISTEN_RANGE = 20.0;
integer listen_handle = -1;

string RECEPTIONIST_NAME = "Rose";

// Session tracking
list active_sessions = []; // [avatarKey, sessionId, timestamp, ...]
integer SESSION_TIMEOUT = 1800; // 30 minutes

// Conversation state
key current_speaker = NULL_KEY;
integer waiting_for_response = FALSE;

default
{
    state_entry()
    {
        // Start listening on public chat
        listen_handle = llListen(CHAT_CHANNEL, "", NULL_KEY, "");
        llOwnerSay("Rose Chat Script active - listening on channel " + (string)CHAT_CHANNEL);
        
        // Start timer for session cleanup
        llSetTimerEvent(300.0); // Check every 5 minutes
    }
    
    listen(integer channel, string name, key id, string message)
    {
        // Ignore messages from self
        if (id == llGetKey()) return;
        
        // Check if message is directed at Rose
        string msg_lower = llToLower(message);
        string name_lower = llToLower(RECEPTIONIST_NAME);
        
        // Respond if:
        // 1. Message contains receptionist's name
        // 2. Currently in conversation with this avatar
        // 3. Message is a direct reply (within range and recent)
        
        integer should_respond = FALSE;
        
        if (llSubStringIndex(msg_lower, name_lower) != -1)
        {
            should_respond = TRUE;
        }
        else if (current_speaker == id && !waiting_for_response)
        {
            should_respond = TRUE;
        }
        
        if (should_respond)
        {
            // Get or create session ID for this avatar
            string sessionId = getOrCreateSession(id);
            
            // Extract the actual message (remove name if present)
            string clean_message = message;
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
            
            // Send to backend via Main script
            string payload = (string)id + "|" + name + "|" + clean_message + "|" + sessionId;
            llMessageLinked(LINK_SET, LINK_CHAT_MESSAGE, payload, NULL_KEY);
            
            current_speaker = id;
            waiting_for_response = TRUE;
            
            // Notify wandering script to pause
            llMessageLinked(LINK_SET, LINK_WANDERING_STATE, "CHATTING", id);
        }
    }
    
    link_message(integer sender, integer num, string msg, key id)
    {
        if (num == LINK_SPEAK)
        {
            // Speak the response
            llSay(CHAT_CHANNEL, msg);
            waiting_for_response = FALSE;
            
            // Set timer to resume wandering after conversation ends
            llSetTimerEvent(15.0); // Wait 15 seconds after last message
        }
    }
    
    timer()
    {
        // Clean up old sessions
        integer current_time = llGetUnixTime();
        list new_sessions = [];
        
        integer i;
        for (i = 0; i < llGetListLength(active_sessions); i += 3)
        {
            key avatarKey = llList2Key(active_sessions, i);
            string sessionId = llList2String(active_sessions, i + 1);
            integer timestamp = llList2Integer(active_sessions, i + 2);
            
            if (current_time - timestamp < SESSION_TIMEOUT)
            {
                new_sessions += [avatarKey, sessionId, timestamp];
            }
        }
        
        active_sessions = new_sessions;
        
        // If no recent activity, resume wandering
        if (!waiting_for_response && current_speaker != NULL_KEY)
        {
            llMessageLinked(LINK_SET, LINK_WANDERING_STATE, "IDLE", NULL_KEY);
            current_speaker = NULL_KEY;
            llSetTimerEvent(300.0); // Back to slow cleanup timer
        }
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }
}

string getOrCreateSession(key avatarKey)
{
    // Look for existing session
    integer idx = llListFindList(active_sessions, [avatarKey]);
    
    if (idx != -1)
    {
        // Update timestamp
        active_sessions = llListReplaceList(active_sessions, [llGetUnixTime()], idx + 2, idx + 2);
        return llList2String(active_sessions, idx + 1);
    }
    
    // Create new session
    string sessionId = (string)llGenerateKey();
    active_sessions += [avatarKey, sessionId, llGetUnixTime()];
    
    return sessionId;
}
