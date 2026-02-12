# Animation Naming Convention Guide

## Overview

Rose Receptionist uses an inventory-based animation system with automatic discovery. Animations are automatically detected and categorized based on their names in the object's inventory.

## Naming Pattern

All animations should start with **"anim"** followed by a category tag to be automatically discovered.

## Animation Categories

### Walk Animations
**Pattern:** `anim walk [description]`  
**Usage:** Randomly selected during navigation between waypoints

**Examples:**
- `anim walk casual`
- `anim walk business`
- `anim walk fast`
- `anim walk slow`

### Stand Animations
**Pattern:** `anim stand [description]`  
**Usage:** Reserved for future use (standing idle animations)

**Examples:**
- `anim stand idle`
- `anim stand fidget`
- `anim stand lookround`

### Sit Animations
**Pattern:** `anim sit [description]`  
**Usage:** Reserved for future use (sitting animations)

**Examples:**
- `anim sit chair`
- `anim sit floor`
- `anim sit cross-legged`

### Dance Animations
**Pattern:** `anim dance [description]`  
**Usage:** Reserved for future use (dance animations)

**Examples:**
- `anim dance salsa`
- `anim dance hip-hop`
- `anim dance slow`

### Turn Left Animations
**Pattern:** `anim turnleft [description]`  
**Usage:** Reserved for future use (turning animations)

**Examples:**
- `anim turnleft quick`
- `anim turnleft smooth`

### Turn Right Animations
**Pattern:** `anim turnright [description]`  
**Usage:** Reserved for future use (turning animations)

**Examples:**
- `anim turnright quick`
- `anim turnright smooth`

### Linger Animations
**Pattern:** `anim [tag]` (not matching any special category above)  
**Usage:** Available for selection during waypoint configuration in training mode

**Examples:**
- `anim typing` - Typing on computer
- `anim watering` - Watering plants
- `anim reading` - Reading documents
- `anim phone` - Talking on phone
- `anim coffee` - Drinking coffee
- `anim filing` - Filing documents
- `anim writing` - Writing with pen

## How It Works

1. **Automatic Discovery:** When scripts start or inventory changes, Rose automatically scans all animations in inventory
2. **Categorization:** Animations starting with "anim" are sorted into categories based on their prefix
3. **Logging:** The system reports what it found in chat:
   ```
   🎭 Animation Discovery:
     ✅ 3 walk animations
     ✅ 5 linger animations
   ```
4. **Usage:** Each category is used appropriately:
   - Walk animations: Randomly selected during navigation
   - Linger animations: Available in training mode for waypoint activities
   - Other categories: Reserved for future features

## Adding Animations

1. **Add to Inventory:** Simply add the animation to Rose's inventory with the correct naming pattern
2. **Automatic Detection:** The system automatically rescans and reports:
   ```
   🔄 Inventory changed, rescanning animations...
   ```
3. **Verify:** Check the console output to confirm the animation was detected

## Troubleshooting

### Animation Not Detected
**Problem:** Animation in inventory but not showing up

**Solutions:**
- Verify the animation name starts with "anim" (lowercase)
- Check that the animation is actually an ANIMATION type (not a notecard or script)
- Look for typos in the prefix (e.g., "anim wlak" instead of "anim walk")
- Reset the scripts manually to force a rescan

### Wrong Category
**Problem:** Animation appearing in wrong category or not appearing at all

**Solutions:**
- The system uses exact prefix matching
- "anim walk casual" will be a walk animation
- "anim casual walk" will be a linger animation (doesn't start with "anim walk")
- Order matters: the system checks special categories first, then everything else is linger

### Animation Plays But Looks Wrong
**Problem:** Animation detected but doesn't look right when played

**Solutions:**
- This is an animation content issue, not a naming/detection issue
- Verify the animation file itself is correct
- Test the animation outside of Rose to confirm it works
- Consider the avatar's shape/size when creating animations

## Best Practices

1. **Consistent Naming:** Use a consistent naming scheme for descriptions
   - Good: `anim walk casual`, `anim walk business`, `anim walk fast`
   - Avoid: `anim walk1`, `anim walk2`, `anim walkAnimation`

2. **Descriptive Names:** Use meaningful descriptions that indicate what the animation does
   - Good: `anim typing`, `anim watering`
   - Avoid: `anim 1`, `anim test`

3. **Testing:** Add animations one at a time initially to verify they work correctly

4. **Backup:** Keep a copy of your animations elsewhere in case they need to be restored

## Migration from Old System

If you were using the old configuration-based system:

1. **Remove Config Entries:** Animation sections in RoseConfig.txt are no longer used
2. **Rename Animations:** Rename animations in inventory to follow the new pattern:
   - Old: `casual_walk` → New: `anim walk casual`
   - Old: `wave` → New: `anim wave`
   - Old: `typing` → New: `anim typing`
3. **Test:** Reset scripts and verify animations are detected
4. **Verify:** Check training mode to confirm linger animations appear in menus

## Technical Details

### Scanning Process
The `scanInventoryAnimations()` function:
1. Clears all animation lists
2. Loops through all INVENTORY_ANIMATION items
3. For each animation starting with "anim":
   - Checks against special category prefixes in order
   - First match wins (e.g., "anim walk" is checked before generic "anim")
   - Non-matching "anim [tag]" goes to linger animations
4. Reports findings to owner

### Performance
- Animation scanning is very fast (happens at startup and on inventory changes)
- No impact on navigation or waypoint performance
- Automatic rescanning ensures animations are always current

### Limitations
- Maximum of ~100 animations per category (LSL list memory limit)
- Animation names are case-sensitive
- Only animations starting with "anim" are processed
- Other animations in inventory are ignored

## Examples

### Example Setup for Receptionist
```
Inventory:
├── Scripts/
├── Animations/
│   ├── anim walk casual      ← Navigation
│   ├── anim walk business    ← Navigation
│   ├── anim typing           ← Linger: working at desk
│   ├── anim watering         ← Linger: watering plants
│   ├── anim phone            ← Linger: answering phone
│   ├── anim coffee           ← Linger: coffee break
│   └── anim filing           ← Linger: filing documents
└── Other items...
```

### Expected Console Output
```
Rose Prim-Based Navigation System active
Reading configuration from RoseConfig...
Configuration loaded.
✅ Loaded 5 attachables
🎭 Animation Discovery:
  ✅ 2 walk animations
  ✅ 5 linger animations
```

## Support

For questions or issues with the animation system:
1. Check this documentation first
2. Verify naming conventions are correct
3. Check console output for detection logs
4. Review the TRAINING_MODE_FIX_TESTING.md for testing procedures
