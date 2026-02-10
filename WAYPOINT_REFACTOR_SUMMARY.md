# Waypoint Configuration Refactor - Implementation Summary

## Overview

This refactor moves waypoint configuration from prim descriptions (which have severe 127-character limits) to a dedicated `[WPP]WaypointConfig` notecard with an interactive training wizard.

## Changes Made

### 1. New Files Created

#### `[WPP]WaypointConfig.notecard`
- Template notecard for waypoint configurations
- Format: `WAYPOINT<number>=<JSON>`
- Includes example configurations
- No character limits (unlike prim descriptions)

#### `RoseReceptionist_Training.lsl`
- Interactive training wizard script
- Authorization-protected training mode
- Replace/Append mode support
- Dialog-based waypoint configuration
- Automatic JSON generation

### 2. Modified Files

#### `RoseReceptionist_GoWander3.lsl`
- Added waypoint config notecard reading
- Falls back to prim descriptions if notecard not available (backward compatibility)
- Auto-reload on `[WPP]WaypointConfig` changes
- Dual notecard reader (RoseConfig + WaypointConfig)

#### `RoseReceptionist_Main.lsl`
- Added user menu for non-admin touches
- "Get Attention" button triggers wave animation
- "Training Mode" button starts training wizard
- Authorization check using OWNER_UUIDS
- RECEPTIONIST_NAME configuration support

#### `RoseConfig.notecard`
- Added `RECEPTIONIST_NAME` setting
- Added `IGNORE_ITEMS` configuration
- Enhanced documentation

#### `docs/WAYPOINT_SYSTEM.md`
- Completely rewritten to focus on notecard system
- Documented training wizard with authorization
- Documented Replace vs. Add New modes
- Updated all examples to use notecard format
- Removed legacy prim description focus

## Key Features

### Authorization System

**Authorized Users:**
- Object owner (always authorized)
- Users listed in `OWNER_UUID` or `OWNER_UUID_1`, `OWNER_UUID_2`, etc. in RoseConfig

**Unauthorized Users:**
- Receive polite message: "Sorry, I'm not authorized to take training from anyone but my managers..."
- Owner is notified of unauthorized access attempts

### Training Modes

#### Replace All Mode
- Starts numbering from WAYPOINT0
- Intended for complete reconfiguration
- User should delete all existing WAYPOINT lines and paste new ones

#### Add New Mode
- Starts numbering from WAYPOINT(N+1) where N is last existing waypoint
- Preserves existing configurations
- User should append new WAYPOINT lines to existing ones

### Backward Compatibility

The system maintains backward compatibility:
- If no `[WPP]WaypointConfig` notecard exists, uses prim descriptions
- Existing prim description configurations continue to work
- Migration path: Use training wizard to convert prim descriptions to notecard

## Usage Flow

### For Authorized Trainers

1. **Touch Rose** → Select "Training Mode"
2. **Choose Mode** (if waypoints already exist):
   - Replace All: Complete redesign
   - Add New: Extend existing route
   - Cancel: Exit
3. **For Each Waypoint:**
   - Select Type: Transient / Linger / Sit
   - Select Duration: 15s / 30s / 60s / 120s / Custom / Skip
   - Select Animation: (from inventory) / None
   - Select Orientation: North/East/South/West/None
   - Select Attachments: (coming soon) / Done
4. **Copy Output** from chat
5. **Edit Notecard:**
   - Replace All: Delete old, paste new
   - Add New: Keep old, append new
6. **Save** → Scripts auto-reload

### For Regular Users

1. **Touch Rose** → Select "Get Attention"
2. Rose responds with attention-getting behavior
3. Training Mode shows authorization error

## Testing Checklist

### Phase 1: Core Infrastructure
- [ ] Place test waypoint prims (Waypoint0, Waypoint1, Waypoint2)
- [ ] Verify GoWander3 reads from `[WPP]WaypointConfig`
- [ ] Test auto-reload when notecard is edited
- [ ] Verify backward compatibility with prim descriptions
- [ ] Test with empty notecard (should use prim descriptions)

### Phase 2: Training Wizard
- [ ] Test unauthorized access (non-owner, non-OWNER_UUID)
- [ ] Verify polite rejection message
- [ ] Verify owner notification of unauthorized attempt
- [ ] Test authorized access (owner)
- [ ] Test authorized access (OWNER_UUID user)
- [ ] Test waypoint scanning
- [ ] Test menu flow through all waypoint types
- [ ] Verify JSON generation is valid
- [ ] Test with animations in inventory
- [ ] Test with no animations in inventory

### Phase 3: Replace/Append Modes
- [ ] Test Replace All mode with no existing waypoints
- [ ] Test Replace All mode with existing waypoints
- [ ] Verify Replace All starts numbering from 0
- [ ] Test Add New mode with existing waypoints
- [ ] Verify Add New continues numbering correctly
- [ ] Test Cancel option

### Phase 4: User Menu
- [ ] Test touch by owner (should check admin access)
- [ ] Test touch by non-owner (should show user menu)
- [ ] Test "Get Attention" button functionality
- [ ] Test "Training Mode" button for authorized user
- [ ] Test "Training Mode" button for unauthorized user
- [ ] Test "Cancel" button

### Phase 5: Configuration
- [ ] Verify RECEPTIONIST_NAME is read from config
- [ ] Verify RECEPTIONIST_NAME is used in user menu
- [ ] Test OWNER_UUID configuration reading
- [ ] Test multiple OWNER_UUID entries
- [ ] Verify IGNORE_ITEMS is documented (implementation in Training script)

### Integration Testing
- [ ] Test complete workflow: Place prims → Train → Edit notecard → Verify navigation
- [ ] Test mixed mode: Some waypoints in notecard, some in prim descriptions
- [ ] Test script reset behavior
- [ ] Test on_rez behavior
- [ ] Test with WAYPOINT_PREFIX customization
- [ ] Test with very long activity names
- [ ] Test with special characters in JSON

## Migration Guide

### Migrating from Prim Descriptions to Notecard

**Option 1: Manual Migration**
1. Open each waypoint prim
2. Copy the description
3. Format as `WAYPOINT<N>=<description>`
4. Paste into `[WPP]WaypointConfig`
5. Save notecard

**Option 2: Using Training Wizard (Recommended)**
1. Keep your existing prim descriptions as reference
2. Use Training Mode to reconfigure
3. Choose "Replace All"
4. Follow wizard for each waypoint
5. Copy output to notecard

## Known Limitations

1. **Attachments**: Menu UI created but attachment system not fully implemented
2. **Custom Duration**: Menu option exists but defaults to 30s
3. **Animation List**: Limited to first 11 animations in inventory (LSL dialog button limit)
4. **Training Session**: Single-user at a time (no concurrent training sessions)
5. **Menu Timeout**: 60 second timeout on all dialog menus

## Future Enhancements

1. Implement full attachment system
2. Add custom duration textbox input
3. Multi-page animation selection for large inventories
4. Waypoint preview/validation before finalizing
5. Export/import waypoint configurations between objects
6. Visual waypoint editor with in-world markers
7. Undo last waypoint configuration
8. Edit specific waypoint without reconfiguring all

## Security Considerations

- Training mode is authorization-protected
- Unauthorized access attempts are logged
- Owner receives notifications of unauthorized attempts
- Authorization list stored in RoseConfig (internal notecard)
- No external API calls during training

## Performance Notes

- Notecard reading is asynchronous (non-blocking)
- Configuration cached in memory after reading
- Auto-reload only triggers on inventory changes
- Sensor range kept at 50m to balance detection vs. performance

## Support

For issues or questions:
1. Check `docs/WAYPOINT_SYSTEM.md` for detailed documentation
2. Verify all scripts are present and active
3. Check console/chat for error messages
4. Ensure waypoint prims are named correctly
5. Verify OWNER_UUID is set correctly for authorization

## Version Information

- Major Version: 4.0 (Notecard System)
- Scripts Modified: 3 (GoWander3, Main, Training)
- New Scripts: 1 (Training)
- Breaking Changes: None (backward compatible)
- Recommended Migration: Yes (prim descriptions → notecard)
