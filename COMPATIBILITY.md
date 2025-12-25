# Mod Compatibility Guide

This document provides information about Eldertide Armaments compatibility with other popular Baldur's Gate 3 mods.

## Essential Compatibility Mods

### Required for Best Experience

#### BG3 Mod Fixer
- **Status**: ✅ **Required**
- **Link**: [Nexus Mods](https://www.nexusmods.com/baldursgate3/mods/141)
- **Why**: Resolves common mod conflicts, ensures proper loading
- **Note**: Should be placed high in load order

### Optional but Recommended

#### Tutorial Chest Summoning
- **Status**: ✅ Compatible
- **Link**: [Nexus Mods](https://www.nexusmods.com/baldursgate3/mods/457)
- **Why**: Access tutorial chest version of mod
- **Note**: Only needed for tutorial chest version

#### BG3 Script Extender
- **Status**: ✅ Compatible
- **Why**: Enables advanced modding features
- **Note**: Not required but enhances overall modding experience

## Compatibility Categories

### ✅ Fully Compatible

Mods that work without issues alongside Eldertide Armaments:

#### User Interface Mods
- **ImprovedUI** - No conflicts
- **Customizer's Compendium** - Works well together
- **Better Hotbar** - No issues
- **Minimap Mod** - Compatible

#### Visual Enhancement Mods
- **Better Camera** - No conflicts
- **Improved Lighting** - Works together
- **HD Textures** - Compatible
- **Visual Effects Mods** - Generally compatible

#### Quality of Life Mods
- **Basket Equipment** - Compatible
- **Weight Slider** - No issues
- **Fast XP** - Works together
- **Bags Bags Bags** - Compatible
- **Level 20** - Compatible

#### Gameplay Mods
- **5e Spells** - Compatible
- **Transmog** - Works well together
- **Extra Races/Classes** - Compatible
- **Unlock Level Curve** - No conflicts

### ⚠️ Compatible with Notes

Mods that work but require attention or specific load order:

#### Equipment Mods
- **Other Ring/Amulet Mods** - ⚠️ May cause loot table conflicts
  - **Solution**: Use BG3 Mod Fixer, adjust load order
  - **Note**: Items from different mods should both appear
  - **Tip**: Place Eldertide Armaments after other equipment mods

- **Armor Mods** - ⚠️ Usually compatible
  - **Solution**: Ensure both mods use CanMerge in treasure tables
  - **Note**: No direct conflicts expected

- **Weapon Mods** - ⚠️ Usually compatible
  - **Solution**: Standard load order management
  - **Note**: Weapons don't conflict with rings/amulets

#### Loot Distribution Mods
- **Loot Rebalance Mods** - ⚠️ May affect spawn rates
  - **Solution**: Test in-game, check if items spawn
  - **Note**: Mods that heavily modify treasure tables may prevent Eldertide items from appearing
  - **Tip**: Place Eldertide Armaments after loot mods in load order

- **Merchant Inventory Mods** - ⚠️ May conflict
  - **Solution**: Use BG3 Mod Fixer, check merchant stocks
  - **Note**: Both sets of items should appear if properly configured

#### Class/Subclass Mods
- **Class Overhauls** - ⚠️ Generally compatible
  - **Solution**: Load Eldertide Armaments after class mods
  - **Note**: Items designed to work with any class
  - **Caution**: Some abilities may interact unexpectedly with homebrew classes

- **Multiclass Unlocker** - ⚠️ Compatible
  - **Note**: Items work with multiclassed characters
  - **Benefit**: More build variety with Eldertide items

### ❌ Known Conflicts

Mods that may cause issues:

#### Problematic Mod Types
- **Mods that completely replace treasure tables** - ❌ May prevent items from spawning
  - **Why**: If a mod replaces rather than merges tables, Eldertide items won't spawn
  - **Solution**: Choose one or the other, or check if compatibility patch exists

- **Mods that disable treasure generation** - ❌ Will prevent spawns
  - **Why**: Items need treasure tables to spawn
  - **Solution**: Don't use together, or use tutorial chest version

- **Outdated equipment mods** - ❌ May cause crashes
  - **Why**: Old mods may not follow current BG3 modding standards
  - **Solution**: Update all mods, remove outdated ones

#### Specific Reported Conflicts
*As of last update, no specific mods have been reported as definitively incompatible. Report issues on Nexus Mods posts tab.*

## Load Order Recommendations

### Optimal Load Order Structure

```
1. BG3 Mod Fixer
2. Core Game Modifications (Script Extender, etc.)
3. Class/Race Mods
4. Spell Mods
5. General Gameplay Mods
6. Loot Modification Mods
7. Other Equipment Mods
8. Eldertide Armaments
9. UI Mods
10. Cosmetic Mods
```

### Load Order Principles

1. **Foundation First**: Core mods and fixes at top
2. **Content Second**: Gameplay and class mods in middle
3. **Items Third**: Equipment mods including Eldertide
4. **Appearance Last**: Cosmetic and UI mods at bottom

### Using BG3 Mod Manager

The mod manager should automatically suggest load order, but you can:
- **Drag and drop** mods to reorder
- **Read warnings** about conflicts
- **Export order** to save configuration
- **Test in-game** after any changes

## Compatibility Testing

### How to Test Compatibility

1. **Start Fresh**
   - Begin a new game or use a test save
   - Install Eldertide Armaments first
   - Add other mods one by one

2. **Check Functionality**
   - Verify items spawn (visit merchant or open chest)
   - Equip items and check abilities unlock
   - Test spells and passive effects
   - Look for console errors

3. **Test Interactions**
   - Use items with modded classes/spells
   - Check if effects stack properly
   - Verify visual effects display correctly

4. **Monitor Performance**
   - Check for FPS drops
   - Watch for crashes
   - Note any unusual behavior

### Signs of Conflict

- Items don't appear in game
- Game crashes when equipping items
- Abilities don't unlock
- Visual effects don't display
- Console errors mentioning Eldertide
- Merchants missing inventory

## Popular Mod Combinations

### Tested and Working

#### "Power Fantasy" Build
- Eldertide Armaments
- 5e Spells
- Level 20
- Extra Class Features
- **Result**: Very powerful, fun for story mode

#### "Tactical Challenge" Build
- Eldertide Armaments
- Enemy AI Improvements
- Smarter Enemy Positioning
- Difficult Encounters Mod
- **Result**: Balanced power with increased challenge

#### "Complete Overhaul" Build
- Eldertide Armaments
- Multiple Class Mods
- Spell Expansions
- 5e Rules Implementation
- **Result**: Deep customization with item variety

#### "Visual Enhancement" Build
- Eldertide Armaments
- HD Texture Packs
- Visual Effects Mods
- Better Lighting
- **Result**: Beautiful and powerful

### Community-Tested Combinations

Check the Nexus Mods posts tab for user-reported mod lists and compatibility experiences.

## Game Version Compatibility

### Current Version Support

- **BG3 Patch 8 (4.1.1.6758295)**: ✅ Fully supported (Version 1.6.5+)
- **BG3 Hotfix #35 (4.1.1.6995620 / PS5: 4.1.1.7023236)**: ⚠️ Use Eldertide Armaments version 1.6.4
- **BG3 Version 4.0.6.5 and earlier**: ⚠️ Use Eldertide Armaments version 1.6.3 or earlier
- **Previous Patches**: ⚠️ May work but not officially supported
- **Future Patches**: ⚠️ May require updates

**Note**: Game version information can become outdated quickly. Always check the [Nexus Mods page](https://www.nexusmods.com/baldursgate3/mods/3596) for the latest compatibility information with your specific BG3 patch version.

**Version 1.6.5 Changes (2025-12-24)**:
- Updated for BG3 Patch 8 (build 6758295) compatibility - fixes game-breaking 85% loading freeze
- Fixed empty UseCosts on combat spells causing potential loading failures
- Cleaned up redundant MemoryCost declarations for improved performance
- Patch 8 includes crossplay support, new subclasses, and expanded mod support

**Version 1.6.4 Changes (2025-12-24)**:
- Updated for BG3 Hotfix #35 compatibility
- Fixed Hellfire Pact UI corruption bug in temporary camps
- Fixed Astral Champion's Ring summon dismissal freeze
- Various localization improvements

### After Game Updates

**What to do when BG3 updates:**

1. **Wait for Mod Update**
   - Check Nexus Mods page for compatibility news
   - Read update notes carefully
   - Look for reported issues in posts
   - Note: Patch 8 includes improved modding toolkit support

2. **Test Carefully**
   - Backup saves before updating
   - Test in new save first
   - Report any issues
   - Check for version mismatches (can cause 85% loading freeze)

3. **Community Reports**
   - Check posts tab for other users' experiences
   - Share your findings
   - Help identify issues

## Platform Compatibility

### PC (Steam/GOG/Epic)
- ✅ **Fully Supported**
- All features available
- Standard installation process

### Steam Deck
- ✅ **Compatible**
- May require additional setup
- Performance may vary
- Check Steam Deck modding guides

### Console (Xbox/PlayStation)
- ❌ **Not Supported**
- Larian doesn't support mods on console
- No workaround available

## Multiplayer Compatibility

### Host and Clients

**Requirements:**
- **Host must have**: Eldertide Armaments installed
- **Clients must have**: Same version of Eldertide Armaments
- **All players need**: Same load order and mod setup

**Known Issues:**
- Different mod versions can cause desyncs
- Some visual effects may not display for clients
- Items should function properly for all players

**Best Practices:**
- Share mod list before playing
- Use exact same versions
- Test in small session first
- Host saves the game

## Troubleshooting Compatibility Issues

### Step-by-Step Diagnosis

1. **Disable All Mods Except Eldertide**
   - If it works, conflict exists
   - If it doesn't, reinstall Eldertide

2. **Add Mods Back One by One**
   - Re-enable mods individually
   - Test after each addition
   - Note which mod causes issues

3. **Check Load Order**
   - Try different order
   - Place problem mod before/after Eldertide
   - Use BG3 Mod Fixer suggestions

4. **Update Everything**
   - Update game
   - Update all mods
   - Update BG3 Mod Manager
   - Update BG3 Mod Fixer

5. **Seek Community Help**
   - Post on Nexus Mods
   - Include mod list and load order
   - Share error messages
   - Provide save file if needed

### Common Solutions

**Items Don't Spawn:**
- Check load order (Eldertide should be after loot mods)
- Ensure BG3 Mod Fixer is active
- Try tutorial chest version instead

**Game Crashes:**
- Update all mods
- Remove outdated mods
- Verify game files
- Check for mod conflicts

**Visual Glitches:**
- Update graphics drivers
- Check for visual mod conflicts
- Lower graphics settings
- Disable other visual effect mods temporarily

## Reporting Compatibility Issues

### Information to Include

1. **Eldertide Version**: Check meta.lsx
2. **Game Version**: BG3 patch number
3. **Other Mods**: Complete list with versions
4. **Load Order**: Screenshot or text list
5. **Issue Description**: Clear explanation
6. **Steps to Reproduce**: How to recreate issue
7. **Error Messages**: Console errors if any

### Where to Report

- **Nexus Mods Posts Tab**: Community discussion
- **Nexus Mods Bugs Tab**: Official bug tracking
- **GitHub Issues**: If repository is available

## Future Compatibility

### Planned Updates

- Continued support for new BG3 patches
- Compatibility patches for popular mod combinations
- Load order optimization
- Community-requested compatibility features

### Community Contributions

Help improve compatibility:
- Report working mod combinations
- Share successful load orders
- Document compatibility issues
- Suggest compatibility improvements

---

*For the latest compatibility information, visit the [Nexus Mods page](https://www.nexusmods.com/baldursgate3/mods/3596) and check the Posts tab.*
