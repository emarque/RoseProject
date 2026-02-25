# Requirements: HTTP Fix, Schedule-Aware Chat, and Attachment System

## Issue 1: HTTP_BODY_MAXLENGTH Error

### Problem
Getting "HTTP_BODY_MAXLENGTH value is invalid" error from Rose scripts.

### Current State
- RoseReceptionist_Main.lsl: Using 16384 (5 occurrences)
- [WPP]WPReporter.lsl: Using 16384 (1 occurrence) 
- RoseAdminTerminal.lsl: Using 16384 (1 occurrence)

### Solution
Change HTTP_BODY_MAXLENGTH from 16384 to 16000 in all locations.

**Rationale**: While 16384 is the documented maximum, some SL regions may reject this exact value. Using 16000 provides a small safety buffer while still allowing large responses.

### Implementation
Simple find/replace in 3 files:
```lsl
// OLD:
HTTP_BODY_MAXLENGTH, 16384

// NEW:
HTTP_BODY_MAXLENGTH, 16000
```

---

## Issue 2: Schedule-Aware Chat Responses

### Problem
Rose responds the same way regardless of whether she's working, off-duty, or sleeping. She should behave differently based on schedule period.

### Requirements

#### Schedule Period Flags
Each period needs two boolean flags:
1. **at_work**: TRUE when she's on duty as receptionist
2. **is_awake**: TRUE when she's conscious and alert

#### Period Behaviors

**WORK Period** (09:00-17:00):
- at_work = TRUE
- is_awake = TRUE  
- Proactively greet visitors
- Respond normally to all chat
- Handle work-related requests

**AFTER_WORK Period** (17:00-22:00):
- at_work = FALSE
- is_awake = TRUE
- No proactive greetings
- Respond to mentions normally
- Reject work requests: "Sorry, I'm off the clock, can we chat about this tomorrow?"

**NIGHT Period** (22:00-09:00):
- at_work = FALSE
- is_awake = FALSE
- No proactive greetings
- Require 3 normal mentions OR 1 shouted mention to respond
- Respond with annoyance: "huh? sorry, it's late, can this wait until tomorrow?"

### Implementation Plan

#### 1. RoseConfig.txt Changes
Add after NIGHT_START_TIME (line 62):
```
# Schedule Period Behavior Flags
# Control Rose's responsiveness based on time of day
WORK_AT_WORK=TRUE
WORK_IS_AWAKE=TRUE
AFTERWORK_AT_WORK=FALSE
AFTERWORK_IS_AWAKE=TRUE
NIGHT_AT_WORK=FALSE
NIGHT_IS_AWAKE=FALSE
# Number of mentions required when sleeping (normal chat)
SLEEP_MENTION_THRESHOLD=3
```

#### 2. Link Message Constants
Add to all relevant scripts:
```lsl
integer LINK_GET_SCHEDULE_INFO = 5000;
integer LINK_SCHEDULE_INFO = 5001;
```

#### 3. [WPP]WPManager.lsl Changes

**New Variables** (after line 33):
```lsl
// Schedule period behavior flags
integer work_at_work = TRUE;
integer work_is_awake = TRUE;
integer afterwork_at_work = FALSE;
integer afterwork_is_awake = TRUE;
integer night_at_work = FALSE;
integer night_is_awake = FALSE;
integer sleep_mention_threshold = 3;
```

**Config Reading** (in dataserver event, ~line 1450):
```lsl
else if (configKey == "WORK_AT_WORK")
    work_at_work = (value == "TRUE");
else if (configKey == "WORK_IS_AWAKE")
    work_is_awake = (value == "TRUE");
else if (configKey == "AFTERWORK_AT_WORK")
    afterwork_at_work = (value == "TRUE");
else if (configKey == "AFTERWORK_IS_AWAKE")
    afterwork_is_awake = (value == "TRUE");
else if (configKey == "NIGHT_AT_WORK")
    night_at_work = (value == "TRUE");
else if (configKey == "NIGHT_IS_AWAKE")
    night_is_awake = (value == "TRUE");
else if (configKey == "SLEEP_MENTION_THRESHOLD")
    sleep_mention_threshold = (integer)value;
```

**New Function**:
```lsl
// Get current schedule period flags
// Returns: "PERIOD|at_work|is_awake|threshold"
string getScheduleInfo()
{
    string period = getCurrentSchedulePeriod();
    integer at_work = FALSE;
    integer is_awake = TRUE;
    
    if (period == "WORK")
    {
        at_work = work_at_work;
        is_awake = work_is_awake;
    }
    else if (period == "AFTER_WORK")
    {
        at_work = afterwork_at_work;
        is_awake = afterwork_is_awake;
    }
    else // NIGHT
    {
        at_work = night_at_work;
        is_awake = night_is_awake;
    }
    
    string at_work_str = "0";
    if (at_work) at_work_str = "1";
    
    string is_awake_str = "0";
    if (is_awake) is_awake_str = "1";
    
    return period + "|" + at_work_str + "|" + is_awake_str + "|" + (string)sleep_mention_threshold;
}
```

**Link Message Handler** (in link_message event):
```lsl
if (num == LINK_GET_SCHEDULE_INFO)
{
    string info = getScheduleInfo();
    llMessageLinked(LINK_SET, LINK_SCHEDULE_INFO, info, NULL_KEY);
}
```

#### 4. RoseReceptionist_Chat.lsl Changes

**New Variables** (after line 32):
```lsl
// Schedule-aware behavior
integer LINK_GET_SCHEDULE_INFO = 5000;
integer LINK_SCHEDULE_INFO = 5001;

string current_period = "WORK";
integer is_at_work = TRUE;
integer is_awake = TRUE;
integer sleep_threshold = 3;

// Mention tracking for sleep mode [avatar_key, count, timestamp, ...]
list mention_counters = [];
integer MENTION_TIMEOUT = 300; // 5 minutes
```

**New Function** (before default state):
```lsl
// Track mentions for sleeping period
incrementMentionCounter(key avatar)
{
    integer current_time = llGetUnixTime();
    integer idx = llListFindList(mention_counters, [avatar]);
    
    if (idx != -1)
    {
        // Found existing counter
        integer count = llList2Integer(mention_counters, idx + 1);
        integer timestamp = llList2Integer(mention_counters, idx + 2);
        
        // Check if it's expired
        if (current_time - timestamp > MENTION_TIMEOUT)
        {
            // Reset counter
            mention_counters = llListReplaceList(mention_counters, [1, current_time], idx + 1, idx + 2);
        }
        else
        {
            // Increment counter
            mention_counters = llListReplaceList(mention_counters, [count + 1, current_time], idx + 1, idx + 2);
        }
    }
    else
    {
        // New counter
        mention_counters += [avatar, 1, current_time];
    }
}

integer getMentionCount(key avatar)
{
    integer idx = llListFindList(mention_counters, [avatar]);
    if (idx != -1)
    {
        integer current_time = llGetUnixTime();
        integer timestamp = llList2Integer(mention_counters, idx + 2);
        
        // Check if expired
        if (current_time - timestamp > MENTION_TIMEOUT)
        {
            return 0;
        }
        
        return llList2Integer(mention_counters, idx + 1);
    }
    return 0;
}

resetMentionCounter(key avatar)
{
    integer idx = llListFindList(mention_counters, [avatar]);
    if (idx != -1)
    {
        mention_counters = llDeleteSubList(mention_counters, idx, idx + 2);
    }
}
```

**Modified listen Event** (replace current listen, ~line 123):
```lsl
listen(integer channel, string name, key id, string message)
{
    // Ignore messages from self
    if (id == llGetKey()) return;
    
    // Query current schedule info
    llMessageLinked(LINK_SET, LINK_GET_SCHEDULE_INFO, "", NULL_KEY);
    
    // Check if message is for Rose
    if (!isMessageForRose(message, id))
    {
        return;
    }
    
    // Check if shouted (for sleep mode)
    integer is_shout = FALSE;
    // Note: LSL doesn't directly detect shouts in listen, would need llListen with separate channel
    // or check message format/all-caps as heuristic
    
    // Handle sleep mode (not awake)
    if (!is_awake)
    {
        incrementMentionCounter(id);
        integer mentions = getMentionCount(id);
        
        // Require threshold mentions or 1 shout
        if (mentions < sleep_threshold && !is_shout)
        {
            return; // Ignore - not enough mentions
        }
        
        // Respond with annoyance
        resetMentionCounter(id);
        string response = "huh? sorry, it's late, can this wait until tomorrow?";
        llSay(CHAT_CHANNEL, response);
        
        // Add to transcript
        addToTranscript(name, message);
        addToTranscript(RECEPTIONIST_NAME, response);
        
        return;
    }
    
    // Handle off-duty (awake but not at work)
    if (!is_at_work)
    {
        // Check if message is work-related (heuristic: contains work keywords)
        string msg_lower = llToLower(message);
        if (llSubStringIndex(msg_lower, "work") != -1 ||
            llSubStringIndex(msg_lower, "job") != -1 ||
            llSubStringIndex(msg_lower, "task") != -1 ||
            llSubStringIndex(msg_lower, "duty") != -1 ||
            llSubStringIndex(msg_lower, "shift") != -1)
        {
            string response = "Sorry, I'm off the clock, can we chat about this tomorrow?";
            llSay(CHAT_CHANNEL, response);
            
            // Add to transcript
            addToTranscript(name, message);
            addToTranscript(RECEPTIONIST_NAME, response);
            
            return;
        }
    }
    
    // Normal processing (existing code continues...)
    // [Rest of current listen implementation]
}
```

**New Link Message Handler** (add to link_message event):
```lsl
link_message(integer sender, integer num, string msg, key id)
{
    if (num == LINK_SCHEDULE_INFO)
    {
        // Parse: "PERIOD|at_work|is_awake|threshold"
        list parts = llParseString2List(msg, ["|"], []);
        current_period = llList2String(parts, 0);
        is_at_work = (llList2Integer(parts, 1) == 1);
        is_awake = (llList2Integer(parts, 2) == 1);
        sleep_threshold = llList2Integer(parts, 3);
    }
    else if (num == LINK_SPEAK)
    {
        // [Existing code...]
    }
}
```

#### 5. RoseReceptionist_Sensor.lsl Changes (Optional)
Disable proactive greetings when not at_work:
- Query schedule info before greeting
- Only greet if at_work flag is TRUE

---

## Issue 3: Attachment System (Rez/Link/Position)

### Problem
Attaching inventory objects to non-avatar objects doesn't work in LSL. Need to rez objects and link them as child prims.

### Requirements

1. **Rez objects** from inventory at activity start
2. **Link rezzed objects** as child prims to main object
3. **Position/rotate** linked objects relative to root prim
4. **Support configuration** of position/rotation per attachment
5. **Derez/unlink** objects at activity end
6. **Handle multiple** simultaneous attachments

### Technical Approach

#### LSL Functions Needed
- `llRezObject(string inventory, vector pos, vector vel, rotation rot, integer start_param)`
- `object_rez(key id)` event to capture rezzed object
- `llCreateLink(key target, integer parent)` to link object
- `llSetLinkPrimitiveParamsFast(integer link, list rules)` to position
- `llBreakLink(integer link)` to detach
- `llGetNumberOfPrims()` to track links

#### Waypoint JSON Format
```json
"attachments": [
  {
    "item": "Clipboard",
    "pos": "<0.1, 0, 0.5>",
    "rot": "<0, 0, 0, 1>"
  },
  {
    "item": "Coffee Mug",
    "pos": "<-0.1, 0, 0.5>",
    "rot": "<0, 0, 0, 1>"
  }
]
```

### Implementation Plan

#### 1. [WPP]WPManager.lsl Changes

**New Variables** (after line 65):
```lsl
// Attachment system
list attached_objects = []; // [link_number, object_name, link_number, object_name, ...]
list pending_attachments = []; // [item_name, pos_vector, rot, item_name, pos_vector, rot, ...]
integer rezzing_attachment = FALSE;
string current_rez_item = "";
```

**New Functions**:
```lsl
// Parse attachment JSON and start rezzing
attachObjects(string attachJson)
{
    if (attachJson == "" || attachJson == "[]")
        return;
    
    debugSay("Parsing attachments: " + attachJson);
    
    // Remove brackets
    attachJson = llStringTrim(attachJson, STRING_TRIM);
    if (llGetSubString(attachJson, 0, 0) == "[")
        attachJson = llGetSubString(attachJson, 1, -2);
    
    // Split by objects (simplified parser - real JSON parsing is complex in LSL)
    // Expected format: [{"item":"Name","pos":"<x,y,z>","rot":"<x,y,z,s>"},...]
    
    // For each attachment object in JSON
    list items = llParseString2List(attachJson, ["},"], []);
    integer i;
    for (i = 0; i < llGetListLength(items); i++)
    {
        string item_json = llList2String(items, i);
        
        // Extract item name
        integer item_start = llSubStringIndex(item_json, "\"item\":\"");
        if (item_start == -1) continue;
        item_start += 8;
        integer item_end = llSubStringIndex(llGetSubString(item_json, item_start, -1), "\"");
        string item_name = llGetSubString(item_json, item_start, item_start + item_end - 1);
        
        // Extract position
        integer pos_start = llSubStringIndex(item_json, "\"pos\":\"");
        vector pos = ZERO_VECTOR;
        if (pos_start != -1)
        {
            pos_start += 7;
            integer pos_end = llSubStringIndex(llGetSubString(item_json, pos_start, -1), "\"");
            string pos_str = llGetSubString(item_json, pos_start, pos_start + pos_end - 1);
            pos = (vector)pos_str;
        }
        
        // Extract rotation
        integer rot_start = llSubStringIndex(item_json, "\"rot\":\"");
        rotation rot = ZERO_ROTATION;
        if (rot_start != -1)
        {
            rot_start += 7;
            integer rot_end = llSubStringIndex(llGetSubString(item_json, rot_start, -1), "\"");
            string rot_str = llGetSubString(item_json, rot_start, rot_start + rot_end - 1);
            rot = (rotation)rot_str;
        }
        
        // Add to pending queue
        pending_attachments += [item_name, pos, rot];
    }
    
    // Start rezzing first attachment
    rezNextAttachment();
}

rezNextAttachment()
{
    if (llGetListLength(pending_attachments) == 0)
    {
        rezzing_attachment = FALSE;
        return;
    }
    
    // Get next attachment
    string item_name = llList2String(pending_attachments, 0);
    vector pos = llList2Vector(pending_attachments, 1);
    rotation rot = llList2Rot(pending_attachments, 2);
    
    // Remove from pending
    pending_attachments = llDeleteSubList(pending_attachments, 0, 2);
    
    // Check if item exists in inventory
    if (llGetInventoryType(item_name) != INVENTORY_OBJECT)
    {
        llOwnerSay("⚠️ Attachment object not found: " + item_name);
        rezNextAttachment(); // Try next
        return;
    }
    
    // Rez object at character's position with offset
    vector rez_pos = llGetPos() + pos;
    
    current_rez_item = item_name;
    rezzing_attachment = TRUE;
    
    debugSay("Rezzing attachment: " + item_name);
    llRezObject(item_name, rez_pos, ZERO_VECTOR, rot, 0);
}

// Detach all attached objects
detachAllObjects()
{
    if (llGetListLength(attached_objects) == 0)
        return;
    
    debugSay("Detaching " + (string)(llGetListLength(attached_objects) / 2) + " objects");
    
    // Break links (from highest to lowest to avoid shifting)
    integer i;
    for (i = llGetListLength(attached_objects) - 2; i >= 0; i -= 2)
    {
        integer link_num = llList2Integer(attached_objects, i);
        string obj_name = llList2String(attached_objects, i + 1);
        
        debugSay("Unlinking: " + obj_name + " (link " + (string)link_num + ")");
        
        // Break link
        if (link_num > 1 && link_num <= llGetNumberOfPrims())
        {
            llBreakLink(link_num);
        }
    }
    
    // Clear list
    attached_objects = [];
}
```

**New Event Handler**:
```lsl
object_rez(key id)
{
    if (!rezzing_attachment)
        return;
    
    debugSay("Object rezzed: " + current_rez_item);
    
    // Request permissions to link
    llRequestPermissions(id, PERMISSION_CHANGE_LINKS);
    
    // Note: Linking happens in run_time_permissions event
}

run_time_permissions(integer perm)
{
    if (perm & PERMISSION_CHANGE_LINKS)
    {
        // Link the rezzed object
        integer num_prims_before = llGetNumberOfPrims();
        
        // Create link (this object as parent)
        llCreateLink(llGetPermissionsKey(), TRUE);
        
        // Wait a moment for link to complete
        llSleep(0.5);
        
        integer num_prims_after = llGetNumberOfPrims();
        
        if (num_prims_after > num_prims_before)
        {
            // Successfully linked
            integer new_link = num_prims_after; // New child is last link number
            
            debugSay("Linked " + current_rez_item + " as link " + (string)new_link);
            
            // Add to tracking list
            attached_objects += [new_link, current_rez_item];
            
            // Position the linked object
            // (Position was already set during rez, but can adjust here if needed)
            
            // Continue with next attachment
            rezNextAttachment();
        }
        else
        {
            llOwnerSay("⚠️ Failed to link " + current_rez_item);
            rezNextAttachment();
        }
    }
}
```

**Integration** (modify processWaypoint function, ~line 950):
```lsl
// After setting up activity animations:
if (attachments_json != "")
{
    attachObjects(attachments_json);
}
```

**Integration** (modify activity completion, ~line 1230 and 1252):
```lsl
// Before moving to next waypoint:
detachAllObjects();
```

**Integration** (modify switchWaypointConfig, ~line 370):
```lsl
// When switching configs:
detachAllObjects();
```

---

## Testing Checklist

### HTTP Fix
- [ ] Compile all three scripts successfully
- [ ] Test HTTP requests complete without errors
- [ ] Verify responses are received

### Schedule Chat
- [ ] Test WORK period: Normal responses
- [ ] Test AFTER_WORK period: "off the clock" response to work requests
- [ ] Test NIGHT period: Requires 3 mentions, responds with "it's late"
- [ ] Test proactive greetings only during WORK

### Attachments
- [ ] Test single attachment: Rezzes, links, positions correctly
- [ ] Test multiple attachments: All attach properly
- [ ] Test activity completion: All detach properly
- [ ] Test config switch: Attachments clean up
- [ ] Test missing inventory item: Graceful error handling

---

## Risk Assessment

**HTTP Fix**: Very Low
- Simple value change
- Well-tested LSL constant
- No behavior changes

**Schedule Chat**: Medium
- Adds conditional logic to chat
- Changes user-facing behavior
- May need fine-tuning of responses

**Attachments**: Medium-High
- Complex object lifecycle management
- Permissions and linking required
- Potential for orphaned objects if errors occur
- Needs thorough testing

---

## Rollback Plan

Each feature can be rolled back independently:

1. **HTTP**: Revert constant to 16384
2. **Schedule Chat**: Remove config flags, remove conditional logic
3. **Attachments**: Comment out attachObjects() and detachAllObjects() calls

