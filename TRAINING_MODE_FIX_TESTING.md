# Training Mode Fix - Testing Guide

## Summary of Changes

This document describes the changes made to fix training mode issues and add walk animation support.

## Issues Fixed

### 1. Training Mode Touch Handling
**Problem**: During training mode, taps from any user would open the original menu instead of registering as waypoint configuration taps.

**Solution**: 
- Training script now sends link messages (LINK_TRAINING_ACTIVE, LINK_TRAINING_COMPLETE, LINK_TRAINING_CANCEL) to notify other scripts of training state
- Main script tracks training mode state and the training user
- Main script's touch_start event now checks if training is active and only allows the training user to interact
- All other users' touches are ignored during training mode

### 2. Training Mode Timeout
**Problem**: Training mode had a 5-minute timeout which was too long.

**Solution**: Changed timeout from 300 seconds to 30 seconds for each waypoint configuration step.

### 3. Walk Animations
**Problem**: Rose didn't play any walk animations when navigating between waypoints.

**Solution**:
- Added [AvailableWalkAnimations] section to RoseConfig.txt
- GoWander3 script now reads walk animations from config
- Randomly selects a walk animation when starting navigation
- Stops walk animation when arriving at waypoint or navigation is interrupted

## Testing Instructions

### Test 1: Training Mode - Authorized User
1. Ensure your UUID is in the OWNER_UUID list in RoseConfig
2. Touch Rose
3. Select "Training Mode"
4. Confirm to start training
5. **Expected**: Training mode activates, you receive instructions to tap at waypoints
6. Tap Rose at different locations
7. **Expected**: Each tap opens the waypoint configuration menu (Type selection)
8. Configure a few waypoints by going through the menus
9. **Expected**: Each waypoint is saved and you're prompted to tap at the next location

### Test 2: Training Mode - Other Users Cannot Interfere
1. Have user A start training mode (as in Test 1)
2. While training is active, have user B touch Rose
3. **Expected**: User B's touch is ignored, no menu appears for user B
4. Only user A should be able to interact during training
5. User A completes or cancels training
6. **Expected**: After training ends, user B can now touch Rose and get the menu

### Test 3: Training Mode Timeout
1. Start training mode
2. Wait 30 seconds without interacting
3. **Expected**: Training times out with message "⏱️ Training session timed out."
4. Touch Rose again
5. **Expected**: Normal menu appears (training mode exited)

### Test 4: Walk Animations
1. Add walk animation names to RoseConfig under [AvailableWalkAnimations]:
   ```
   [AvailableWalkAnimations]
   casual_walk
   business_walk
   ```
2. Ensure these animations exist in Rose's inventory
3. Reset scripts or reload configuration
4. **Expected**: Console shows "✅ Loaded 2 walk animations"
5. Observe Rose navigating between waypoints
6. **Expected**: Rose plays a walk animation while moving
7. **Expected**: Walk animation stops when Rose arrives at waypoint
8. **Expected**: Different animations may be used for different navigation segments (random selection)

### Test 5: Walk Animation - Navigation Interruption
1. Rose starts navigating (walk animation playing)
2. Touch Rose to interact
3. **Expected**: Navigation stops and walk animation stops
4. Complete interaction
5. **Expected**: Rose resumes navigation with a new walk animation

## Configuration Examples

### RoseConfig.txt - Walk Animations Section
```
[AvailableWalkAnimations]
# Add walk animations here - one per line
# These animations will be randomly selected during navigation
walk_casual
walk_business
walk_slow
stroll
```

### Common Issues

**Issue**: Walk animations don't play
- **Check**: Are the animation names in RoseConfig exactly matching the inventory names?
- **Check**: Do the animations exist in Rose's inventory?
- **Check**: Did you reload/reset scripts after adding animations?

**Issue**: Training mode still shows menu to other users
- **Check**: Did all scripts reload properly?
- **Check**: Are you testing with different users (not the same user in different viewers)?

**Issue**: Training times out too quickly
- **Solution**: 30 seconds is intentional per the requirements. Complete each waypoint configuration within 30 seconds.

## Technical Details

### Link Messages Used
- `LINK_TRAINING_ACTIVE (3002)`: Sent when training starts, includes training user key
- `LINK_TRAINING_COMPLETE (3001)`: Sent when training completes successfully
- `LINK_TRAINING_CANCEL (3003)`: Sent when training is cancelled or times out

### State Variables Added
- `training_mode_active`: Boolean flag in Main script
- `training_mode_user`: Key of the user currently training
- `available_walk_animations`: List of configured walk animation names in GoWander3
- `current_walk_animation`: Currently playing walk animation in GoWander3

### Functions Added
- `startWalkAnimation()`: Randomly selects and starts a walk animation
- `stopWalkAnimation()`: Stops the current walk animation

## Files Modified
1. `RoseReceptionist_Training.lsl` - Link message notifications, timeout changes
2. `RoseReceptionist_Main.lsl` - Training state tracking, touch filtering
3. `RoseReceptionist_GoWander3.lsl` - Walk animation system
4. `RoseConfig.txt` - Added [AvailableWalkAnimations] section

## Verification Checklist
- [ ] Training mode only responds to training user's taps
- [ ] Other users cannot interfere during training
- [ ] Training timeout is 30 seconds per waypoint
- [ ] Walk animations play during navigation
- [ ] Walk animations stop at arrival
- [ ] Random walk animation selection works
- [ ] Walk animations stop when navigation interrupted
