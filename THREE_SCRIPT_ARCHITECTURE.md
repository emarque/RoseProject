# GoWander3 Three-Script Architecture

## Overview

The GoWander3 navigation system is split into three specialized scripts that communicate via link messages:

1. **Navigator** (7KB) - Handles physical movement
2. **Waypoint Manager** (26KB) - Determines next destination and manages activity state
3. **Activity Reporter** (7KB) - Tracks and reports activities to API

Total: 40KB (vs original 54KB monolith)

## Script Responsibilities

### 1. [WPP]WPNavigator.lsl (7KB)

**Purpose**: Execute physical movement via keyframed motion

**Responsibilities**:
- Keyframed motion control
- Walk animation playback
- Position tracking and arrival detection
- Navigation timeout handling
- Rotation calculation before movement

**Key Functions**:
- `navigateToTarget(vector, key)` - Move to position
- `stopNavigation()` - Stop movement
- `startWalkAnimation()` / `stopWalkAnimation()` - Animation control

**Messages Received**:
- `LINK_NAV_GOTO (3000)` - Command to navigate to position
- `LINK_WANDERING_STATE (2000)` - Interaction state changes

**Messages Sent**:
- `LINK_NAV_ARRIVED (3001)` - Arrived at destination
- `LINK_NAV_TIMEOUT (3002)` - Navigation failed/timed out

### 2. [WPP]WPManager.lsl (26KB)

**Purpose**: Determine next waypoint and manage activity state

**Responsibilities**:
- Waypoint configuration loading from notecard
- Waypoint selection and sequencing logic
- Activity state management (linger/sit/transient)
- Stand animation variation during activities
- Timer management for activity durations
- Configuration reading from RoseConfig
- Home position logic

**Key Functions**:
- `moveToNextWaypoint()` - Select next destination
- `processWaypoint(vector)` - Start activity at location
- `navigateToCurrentWaypoint()` - Tell Navigator where to go
- `switchStandAnimation()` - Vary stand animations
- `loadWaypointConfig()` - Load waypoint definitions

**Messages Received**:
- `LINK_NAV_ARRIVED (3001)` - Navigator arrived
- `LINK_NAV_TIMEOUT (3002)` - Navigation timeout
- `LINK_WANDERING_STATE (2000)` - Interaction state
- `"TOGGLE_WANDER"` - Enable/disable wandering

**Messages Sent**:
- `LINK_NAV_GOTO (3000)` - Tell Navigator to move
- `LINK_ACTIVITY_START (3010)` - Tell Reporter activity started
- `LINK_ACTIVITY_COMPLETE (3011)` - Tell Reporter activity done
- `LINK_ACTIVITY_UPDATE (2001)` - Tell Main script activity name

### 3. [WPP]WPReporter.lsl (7KB)

**Purpose**: Track and report activities to API

**Responsibilities**:
- Receive activity start/complete messages
- Activity batching and queueing
- HTTP requests to API endpoints
- Daily report generation
- Error handling (rate limiting, etc.)
- Current activity tracking

**Key Functions**:
- `queueActivity(name, type, duration)` - Add to batch
- `sendActivityBatch()` - Send batch to API
- `completeActivity(id)` - Mark activity complete
- `generateDailyReport()` - End-of-shift report

**Messages Received**:
- `LINK_ACTIVITY_START (3010)` - Activity started (msg=name, id=type|duration)
- `LINK_ACTIVITY_COMPLETE (3011)` - Activity completed (msg=name)
- `LINK_ACTIVITY_QUERY (3012)` - Get current activity

**Messages Sent**:
- None (responds via HTTP)

## Communication Protocol

### Link Message Numbers

```lsl
// Navigation (Navigator ↔ Waypoint)
integer LINK_NAV_GOTO = 3000;      // Waypoint → Navigator
integer LINK_NAV_ARRIVED = 3001;   // Navigator → Waypoint
integer LINK_NAV_TIMEOUT = 3002;   // Navigator → Waypoint

// Activity Reporting (Waypoint → Reporter)
integer LINK_ACTIVITY_START = 3010;    // Waypoint → Reporter
integer LINK_ACTIVITY_COMPLETE = 3011; // Waypoint → Reporter
integer LINK_ACTIVITY_QUERY = 3012;    // Any → Reporter

// Shared (from other scripts)
integer LINK_WANDERING_STATE = 2000;   // Chat/Sensor → All
integer LINK_ACTIVITY_UPDATE = 2001;   // Waypoint → Main
```

### Message Flow

#### Normal Navigation Sequence

```
Waypoint              Navigator            Reporter
   |                       |                    |
   |--LINK_NAV_GOTO------->|                    |
   |  (position, wpNum)    |                    |
   |                       |                    |
   |                       |--[Moving...]       |
   |                       |                    |
   |<--LINK_NAV_ARRIVED----|                    |
   |  (position, wpNum)    |                    |
   |                       |                    |
   |--processWaypoint()    |                    |
   |                       |                    |
   |--LINK_ACTIVITY_START------------------>|
   |  (name, type|duration)                    |
   |                       |                    |
   |--[Activity timer]     |                    |--[Queue for batch]
   |                       |                    |
   |--[Activity done]      |                    |
   |                       |                    |
   |--LINK_ACTIVITY_COMPLETE----------------->|
   |  (name)               |                    |
   |                       |                    |
   |--moveToNextWaypoint() |                    |
```

#### Activity Start Message Format

**LINK_ACTIVITY_START (3010)**:
- `msg` (string): Activity name (e.g., "Standing at my desk")
- `id` (key): Format `"type|duration"` (e.g., "linger|45")

**Waypoint sends**:
```lsl
llMessageLinked(LINK_SET, LINK_ACTIVITY_START, current_activity_name, 
               (key)(activity_type + "|" + (string)activity_duration));
```

**Reporter receives and parses**:
```lsl
string idStr = (string)id;
integer pipePos = llSubStringIndex(idStr, "|");
string type = llGetSubString(idStr, 0, pipePos - 1);
integer duration = (integer)llGetSubString(idStr, pipePos + 1, -1);
queueActivity(msg, type, duration);
```

## Sequence Diagrams

### Full Activity Cycle

```
1. Navigator moves Rose to waypoint
2. Navigator sends LINK_NAV_ARRIVED to Waypoint
3. Waypoint processes waypoint config
4. Waypoint sends LINK_ACTIVITY_START to Reporter
5. Waypoint starts activity (play animation, set rotation, timer)
6. Waypoint timer checks activity progress
7. When duration complete, Waypoint sends LINK_ACTIVITY_COMPLETE to Reporter
8. Waypoint calls moveToNextWaypoint()
9. Waypoint sends LINK_NAV_GOTO to Navigator
10. Loop continues
```

### Interruption Handling

```
Chat/Sensor          Waypoint         Navigator         Reporter
     |                   |                  |                |
     |--GREETING-------->|                  |                |
     |                   |<-----------------| (also gets)    |
     |                   |                  |                |
     |                   |--Pause timer     |                |
     |                   |                  |--Stop motion   |
     |                   |                  |                |
     |--DONE------------>|                  |                |
     |                   |<-----------------| (also gets)    |
     |                   |                  |                |
     |                   |--Resume          |                |
     |                   |--moveToNextWp()  |                |
```

## Benefits of 3-Script Architecture

### Memory Management
- **Navigator**: 7KB (11% of limit) - room for navigation features
- **Waypoint**: 26KB (41% of limit) - room for waypoint logic
- **Reporter**: 7KB (11% of limit) - room for API features
- **Total**: 40KB vs original 54KB (14KB saved)
- **Headroom**: 24KB per script on average

### Separation of Concerns
1. **Navigation**: Physical movement mechanics isolated
2. **Waypoint Logic**: Activity and routing decisions isolated
3. **API Communication**: External reporting isolated

### Independent Development
- Add navigation features without touching waypoint logic
- Change API reporting without affecting navigation
- Update activity types without modifying movement code

### Testing
- Test each script independently
- Mock link messages for unit testing
- Easier to identify which script has issues

### Performance
- Each script has full 64KB memory stack
- Parallel event processing
- Reduced stack depth per script

## Configuration

All three scripts read from shared notecards:
- `RoseConfig` - Read by Waypoint for parameters
- `[WPP]WaypointConfig` - Read by Waypoint for locations

Animation inventory scanned by:
- Navigator: "anim walk" animations
- Waypoint: "anim stand" and other animations

## Deployment Steps

1. **Remove old scripts** (if present):
   - `RoseReceptionist_GoWander3.lsl` (54KB monolith)
   - `[WPP]WPManager.lsl (old 2-script version)` (31KB 2-script version)

2. **Add new scripts** to object:
   - `[WPP]WPNavigator.lsl`
   - `[WPP]WPManager.lsl`
   - `[WPP]WPReporter.lsl`

3. **Verify** in chat:
   - "Navigator ready"
   - "Waypoint Manager ready"
   - "Reporter ready"

4. **Test** basic functionality:
   - Navigation to waypoints
   - Activity start/stop
   - API reporting (check server logs)

## Troubleshooting

### Navigator Issues
- **Not moving**: Check LINK_NAV_GOTO received
- **Wrong direction**: Verify rotation calculation
- **Stuck**: Check keyframed motion status

### Waypoint Issues
- **No waypoints**: Check config notecard loaded
- **Activities not starting**: Verify waypoint configs parsed
- **Timer not working**: Check activity_duration set

### Reporter Issues
- **No API calls**: Check LINK_ACTIVITY_START received
- **429 errors**: Rate limiting active (normal)
- **Batching**: Activities queue until batch size reached

### Integration Issues
- **Scripts not communicating**: Verify all in same object
- **Messages lost**: Check link message numbers match
- **State desync**: Check current_state in each script

## Memory Usage

| Script | Size | % of 64KB | Headroom |
|--------|------|-----------|----------|
| Navigator | 7KB | 11% | 57KB (89%) |
| Waypoint | 26KB | 41% | 38KB (59%) |
| Reporter | 7KB | 11% | 57KB (89%) |
| **Total** | **40KB** | **21%** | **152KB total** |

Compared to original:
- Original monolith: 54KB (84% of limit)
- 3-script system: 40KB total (21% per-script average)
- **Savings**: 14KB in consolidated size
- **Benefit**: Each script has 64KB stack vs shared

## Future Enhancements

### Navigator
- Obstacle avoidance
- Flight navigation
- Variable speed
- Path smoothing

### Waypoint
- Dynamic waypoint generation
- Time-based scheduling
- Multi-avatar coordination
- Complex activity types

### Reporter
- Enhanced analytics
- Activity recommendations
- Performance metrics
- Offline queuing

Each enhancement can be developed independently without affecting other scripts.
