# GoWander3 Script Split Architecture

## Problem

The GoWander3 script grew to 54KB, causing stack heap collisions in LSL's 64KB memory limit. With continued feature additions, the risk of hitting the limit increased.

## Solution

Split the monolithic script into two specialized scripts that communicate via link messages:

### 1. [WPP]WPNavigator.lsl (7KB)
**Purpose**: Handle actual navigation and movement mechanics

**Responsibilities**:
- Keyframed motion control
- Walk animation playback and management
- Position tracking and arrival detection
- Navigation timeout handling
- Responding to movement commands from Manager

**Key Functions**:
- `navigateToTarget(vector, key)` - Execute movement to position
- `stopNavigation()` - Stop current movement
- `startWalkAnimation()` / `stopWalkAnimation()` - Manage walk animations
- `scanInventoryAnimations()` - Load available walk animations

**State Management**:
- `current_state`: "IDLE" or "WALKING"
- `is_navigating`: Boolean navigation status
- `current_target_pos`: Target destination
- `navigation_start_time`: For timeout detection

### 2. [WPP]WPManager.lsl (old 2-script version) (31KB)
**Purpose**: Determine next waypoint and manage activities

**Responsibilities**:
- Waypoint configuration loading from notecard
- Activity processing (linger/sit/transient types)
- Stand animation variation during activities
- Activity logging and batch reporting to API
- Waypoint selection and sequencing logic
- Configuration management from RoseConfig
- Timer management for activity durations

**Key Functions**:
- `moveToNextWaypoint()` - Determine next destination
- `processWaypoint(vector)` - Handle activity at waypoint
- `navigateToCurrentWaypoint()` - Instruct Navigator to move
- `switchStandAnimation()` - Vary stand animations during linger
- `queueActivity()` / `sendActivityBatch()` - API reporting
- `loadWaypointConfig()` - Load from notecard

**State Management**:
- `current_state`: "IDLE", "WALKING", "LINGERING", "SITTING", "INTERACTING"
- `current_waypoint_index`: Current position in waypoint sequence
- `activity_type`, `activity_duration`, etc.: Activity details
- `waypoint_configs`: Loaded waypoint data

## Communication Protocol

The scripts communicate via link messages:

### Manager → Navigator

**LINK_NAV_GOTO (3000)**
- **Purpose**: Command Navigator to move to position
- **Parameters**:
  - `msg`: Vector position as string
  - `id`: Waypoint key/identifier
- **Sent by**: Manager when ready to navigate to next waypoint
- **Example**: `llMessageLinked(LINK_SET, LINK_NAV_GOTO, (string)target_pos, (key)wpNumber);`

### Navigator → Manager

**LINK_NAV_ARRIVED (3001)**
- **Purpose**: Notify Manager that destination was reached
- **Parameters**:
  - `msg`: Final position as string
  - `id`: Waypoint key that was reached
- **Sent by**: Navigator when within tolerance of target
- **Triggers**: Manager calls `processWaypoint()` to start activity

**LINK_NAV_TIMEOUT (3002)**
- **Purpose**: Notify Manager that navigation failed/timed out
- **Parameters**:
  - `msg`: Empty string
  - `id`: Waypoint key that failed
- **Sent by**: Navigator after NAVIGATION_TIMEOUT seconds
- **Triggers**: Manager calls `moveToNextWaypoint()` to try next location

### Shared Messages (from other scripts)

**LINK_WANDERING_STATE (2000)**
- Used by Chat/Sensor scripts to notify of interactions
- Both scripts listen for "GREETING", "CHATTING", "DONE"
- Navigator: Stops movement during interaction
- Manager: Pauses activity timers during interaction

**LINK_ACTIVITY_UPDATE (2001)**
- Manager sends to Main script when activity starts
- Allows Main to track current activity for responses

## Sequence Diagrams

### Normal Navigation Flow
```
Manager                Navigator              
  |                        |
  |--LINK_NAV_GOTO-------->|  (vector, key)
  |                        |
  |                        |--[Moving via keyframed motion]
  |                        |--[Playing walk animation]
  |                        |--[Checking arrival every 1s]
  |                        |
  |<--LINK_NAV_ARRIVED-----|  (position, key)
  |                        |
  |--[processWaypoint()]   |
  |--[Start activity]      |
  |--[Timer for duration]  |
  |                        |
  |--[Activity complete]   |
  |--LINK_NAV_GOTO-------->|  (next waypoint)
```

### Timeout Flow
```
Manager                Navigator
  |                        |
  |--LINK_NAV_GOTO-------->|
  |                        |
  |                        |--[Moving...]
  |                        |--[60 seconds pass]
  |                        |
  |<--LINK_NAV_TIMEOUT-----|
  |                        |
  |--[moveToNextWaypoint()]|
  |--LINK_NAV_GOTO-------->|  (different waypoint)
```

### Interaction Interruption
```
Manager            Navigator          Chat/Sensor
  |                     |                  |
  |--LINK_NAV_GOTO----->|                  |
  |                     |--[Moving]        |
  |                     |                  |
  |<-----------------LINK_WANDERING_STATE--| (GREETING)
  |                     |<-----------------| (GREETING)
  |                     |                  |
  |--[Pause timers]     |                  |
  |                     |--[Stop movement] |
  |                     |                  |
  |<-----------------LINK_WANDERING_STATE--| (DONE)
  |                     |<-----------------| (DONE)
  |                     |                  |
  |--[Resume: moveToNextWaypoint()]        |
```

## Benefits of Split

### Memory Management
- **Navigator**: 7KB (11% of limit) - room to grow navigation features
- **Manager**: 31KB (48% of limit) - room for activity logic
- **Combined**: 38KB vs original 54KB monolith
- **Headroom**: 26KB available (40% of limit)

### Code Organization
- **Clear separation**: Navigation vs waypoint/activity logic
- **Easier maintenance**: Changes to navigation don't affect activity logic
- **Independent testing**: Each script can be tested separately
- **Specialization**: Each script focused on one responsibility

### Performance
- **Reduced stack usage**: Each script has its own 64KB stack
- **Parallel event handling**: Both scripts process events independently
- **Better memory locality**: Related functions stay together

## Migration from Monolith

### Removed from Original
The original `RoseReceptionist_GoWander3.lsl` (54KB) can be retired once both new scripts are deployed.

### Deployment Process

1. **Add Navigator script** to object
2. **Add Manager script** to object  
3. **Remove old GoWander3** script (optional, can keep as backup initially)
4. **Test** that navigation and activities work correctly
5. **Monitor** for any link message issues

### Configuration
Both scripts read from the same notecards:
- `RoseConfig` - Configuration parameters (Manager reads this)
- `[WPP]WaypointConfig` - Waypoint definitions (Manager reads this)

Both scripts scan the same animation inventory:
- Navigator: Scans for "anim walk" animations
- Manager: Scans for "anim stand" and "anim linger" animations

## Testing Recommendations

### Navigator Testing
1. Send LINK_NAV_GOTO with various positions
2. Verify walk animation plays
3. Verify LINK_NAV_ARRIVED sent on arrival
4. Verify LINK_NAV_TIMEOUT sent after 60s if stuck
5. Verify navigation stops on LINK_WANDERING_STATE

### Manager Testing
1. Verify waypoint config loads correctly
2. Verify activity types processed correctly (transient, linger, sit)
3. Verify stand animation variation works during linger
4. Verify activities complete after duration expires
5. Verify API reporting functions
6. Verify interaction interruptions handled

### Integration Testing
1. Full waypoint loop with multiple stops
2. Activities of varying durations
3. Interruptions during navigation and activities
4. Timeout handling and recovery
5. Configuration changes and reloads

## Future Enhancements

With the split architecture, future additions have clear homes:

### Navigator Enhancements
- Obstacle avoidance
- Smoother rotation during turns
- Variable speed based on terrain
- Jump/fly navigation modes

### Manager Enhancements
- More activity types
- Dynamic waypoint generation
- Time-of-day activity scheduling
- Multi-avatar coordination

## Troubleshooting

### Navigator not moving
- Check that Navigator received LINK_NAV_GOTO message
- Verify walk animations exist in inventory
- Check keyframed motion status

### Manager not sending waypoints
- Check waypoint config loaded (see chat messages)
- Verify at least one waypoint exists
- Check timer is running

### Activities not completing
- Verify Manager timer is active during LINGERING/SITTING
- Check activity_duration is set correctly
- Look for "Activity done" messages in chat

### Scripts not communicating
- Verify both scripts in same object
- Check LINK_SET used for all messages
- Verify link message numbers match in both scripts

## Memory Usage Summary

| Component | Size | % of Limit | Safety Margin |
|-----------|------|------------|---------------|
| Navigator | 7KB | 11% | 57KB (89%) |
| Manager | 31KB | 48% | 33KB (52%) |
| **Total** | **38KB** | **59%** | **26KB (41%)** |

The split provides substantial headroom for future development while eliminating stack heap collision risk.
