# Installation Guide - Eldertide Armaments

This comprehensive guide will help you install Eldertide Armaments correctly and troubleshoot common issues.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation Methods](#installation-methods)
3. [Choosing Your Version](#choosing-your-version)
4. [Step-by-Step Installation](#step-by-step-installation)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Updating the Mod](#updating-the-mod)
8. [Uninstallation](#uninstallation)

## Prerequisites

Before installing Eldertide Armaments, ensure you have:

### Required
- **Baldur's Gate 3** - Latest version (check for updates via Steam/GOG)
- **BG3 Mod Manager** - [Download here](https://github.com/LaughingLeader/BG3ModManager/releases)
- **BG3 Mod Fixer** - [Download from Nexus](https://www.nexusmods.com/baldursgate3/mods/141)
  - Essential for compatibility with other mods
  - Prevents common mod conflicts

### Optional (Recommended)
- **Tutorial Chest Summoning** - [Download from Nexus](https://www.nexusmods.com/baldursgate3/mods/457)
  - Required only if using the Tutorial Chest version
  - Allows easy access to items for testing

### Important Notes
- Always backup your saves before installing mods
- Install mods on a fresh playthrough or at a convenient save point
- Some mods may not be compatible with ongoing save files

## Installation Methods

### Method 1: BG3 Mod Manager (Recommended)

**Why this method?**
- Automatic load order management
- Easy enable/disable of mods
- Prevents common installation errors
- Visual interface for managing mods

**Steps:**

1. **Download the Mod**
   - Go to [Nexus Mods page](https://www.nexusmods.com/baldursgate3/mods/3596)
   - Click "Files" tab
   - Choose your version (Immersive or Tutorial Chest)
   - Download with "Mod Manager Download" or "Manual Download"

2. **Extract the Archive**
   - Extract the downloaded ZIP file
   - You should see a `.pak` file (e.g., `EldertideArmament.pak`)

3. **Install BG3 Mod Fixer First**
   - Download and install BG3 Mod Fixer using same method
   - This is crucial for compatibility

4. **Copy to Mods Folder**
   - Locate your BG3 Mods folder:
     - **Windows**: `%LocalAppData%\Larian Studios\Baldur's Gate 3\Mods`
     - **Steam**: Usually in `C:\Users\[YourName]\AppData\Local\Larian Studios\Baldur's Gate 3\Mods`
   - Copy the `.pak` file to this folder

5. **Configure in BG3 Mod Manager**
   - Open BG3 Mod Manager
   - Click "Refresh" to update mod list
   - Find "EldertideArmament" in the Inactive Mods list
   - Check the box to enable it
   - Ensure BG3 Mod Fixer is also enabled
   - Click "Save Load Order" or "Export Order to Game"

6. **Launch the Game**
   - Start Baldur's Gate 3
   - Load your save or start a new game
   - Check for items (see Verification section)

### Method 2: Manual Installation

**Not recommended for beginners** - Use only if BG3 Mod Manager doesn't work.

**Steps:**

1. **Download and Extract**
   - Download mod from Nexus Mods
   - Extract the `.pak` file

2. **Copy to Mods Folder**
   - Navigate to: `%LocalAppData%\Larian Studios\Baldur's Gate 3\Mods`
   - Create the `Mods` folder if it doesn't exist
   - Copy the `.pak` file here

3. **Edit modsettings.lsx**
   - Navigate to: `%LocalAppData%\Larian Studios\Baldur's Gate 3\PlayerProfiles\Public`
   - Open `modsettings.lsx` with a text editor
   - Add this entry inside the `<node id="ModOrder">` section:

   ```xml
   <node id="Module">
       <attribute id="UUID" value="22b848d1-5fff-4f76-a4f8-8461721e6112" type="FixedString"/>
   </node>
   ```

4. **Add to Mods Section**
   - Also add this entry inside the `<node id="Mods">` section:

   ```xml
   <node id="ModuleShortDesc">
       <attribute id="Folder" value="EldertideArmament" type="LSString"/>
       <attribute id="MD5" value="" type="LSString"/>
       <attribute id="Name" value="EldertideArmament" type="FixedString"/>
       <attribute id="UUID" value="22b848d1-5fff-4f76-a4f8-8461721e6112" type="FixedString"/>
       <attribute id="Version64" value="36873228391546880" type="int64"/>
   </node>
   ```

5. **Save and Launch**
   - Save `modsettings.lsx`
   - Launch the game

## Choosing Your Version

### Immersive Version (Recommended for Regular Play)

**Best for:**
- Normal playthroughs
- Players who enjoy finding loot naturally
- Immersive experience

**How it works:**
- Items scattered across ~40 locations
- Each item spawns only once per playthrough
- Found in merchant inventories, treasure chests, boss loot
- Distributed throughout Acts 1-3

**Locations include:**
- Sorcerous Sundries
- Harper Quartermaster
- Githyanki Quartermaster
- Various hidden chests
- Boss encounters
- Special story locations

### Tutorial Chest Version

**Best for:**
- Testing the mod
- Specific builds
- Quick access to items
- Multiple playthroughs with different builds

**Requirements:**
- Tutorial Chest Summoning mod must be installed
- Works well for experimenting

**How to access:**
- Install Tutorial Chest Summoning mod
- Use the summoning feature in-game
- All items available immediately

## Step-by-Step Installation

### For First-Time Modders

1. **Prepare Your Game**
   - Update BG3 to latest version
   - Backup your save files (found in `%LocalAppData%\Larian Studios\Baldur's Gate 3\PlayerProfiles`)
   - Close the game completely

2. **Install Prerequisites**
   - Download and install BG3 Mod Manager
   - Download BG3 Mod Fixer from Nexus
   - Follow its installation instructions

3. **Find Your Mods Folder**
   - Press `Windows + R`
   - Type: `%LocalAppData%\Larian Studios\Baldur's Gate 3\Mods`
   - Press Enter
   - If the folder doesn't exist, create it

4. **Install Eldertide Armaments**
   - Download from Nexus Mods
   - Extract the ZIP file
   - Copy `.pak` file to Mods folder
   - Open BG3 Mod Manager
   - Enable the mod
   - Save load order

5. **Test Installation**
   - Start the game
   - Load a save or start new game
   - Check for items (see Verification section)

## Verification

### Check Installation Success

1. **In BG3 Mod Manager**
   - Mod should appear in "Active Mods" list
   - Green checkmark indicates it's enabled
   - No error messages in the log

2. **In Game**
   
   **Tutorial Chest Version:**
   - Use Tutorial Chest Summoning
   - Look for Eldertide chest or items
   - Should see rings and amulets with unique icons

   **Immersive Version:**
   - Visit a merchant (e.g., Arron in Druid Grove)
   - Check inventory for Eldertide items
   - May need to rest/level up/long rest for merchant refresh
   - Check treasure chests in various locations
   - Note: RNG means not all locations have items every time

3. **Item Identification**
   - Look for items with "ELDER" prefix in their IDs
   - Unique purple/gold item backgrounds (legendary rarity)
   - Custom icons and descriptions
   - Unique ability descriptions

## Troubleshooting

### Mod Doesn't Appear in Game

**Possible Causes & Solutions:**

1. **Not Properly Enabled**
   - Open BG3 Mod Manager
   - Check if mod is in "Active Mods" list
   - Save load order again
   - Restart the game

2. **Wrong Game Version**
   - Check if your BG3 is up to date
   - Check if mod is compatible with current patch
   - Visit Nexus Mods page for compatibility info

3. **Missing BG3 Mod Fixer**
   - Install BG3 Mod Fixer
   - Enable it in mod manager
   - Place it high in load order

4. **Corrupted Download**
   - Re-download the mod
   - Verify file integrity
   - Extract again

### Items Not Spawning (Immersive Version)

**Solutions:**

1. **RNG Factor**
   - Items have spawn chances in some locations
   - Check multiple merchants and locations
   - Try resting/long resting to refresh merchants

2. **Already Looted**
   - Each item only spawns once per playthrough
   - If you looted an area before installing, item won't appear

3. **Save Game Issue**
   - Try installing mod at game start
   - Some saves may not spawn new loot properly

4. **Load Order**
   - Ensure no other mods conflict with loot tables
   - Try disabling other loot mods temporarily

### Mod Manager Shows Errors

**Common Errors:**

1. **"Mod conflicts detected"**
   - Check which mods conflict
   - Reorder mods (BG3 Mod Fixer should be near top)
   - May need to choose which mod to keep

2. **"Missing dependencies"**
   - Install BG3 Mod Fixer
   - Check for other required mods

3. **"Invalid pak file"**
   - Re-download the mod
   - Ensure file wasn't corrupted
   - Check file size matches Nexus listing

### Game Crashes After Installing

**Steps to Fix:**

1. **Isolate the Issue**
   - Disable all mods except Eldertide Armaments
   - Launch game
   - If it works, re-enable mods one by one

2. **Check Compatibility**
   - Visit Nexus Posts tab
   - Look for reported incompatibilities
   - Update all mods to latest versions

3. **Verify Game Files**
   - Steam: Right-click BG3 > Properties > Verify Integrity
   - GOG: Use GOG Galaxy to verify

4. **Clean Installation**
   - Remove all mods
   - Verify game files
   - Reinstall mods one by one

## Updating the Mod

### When a New Version is Released

1. **Read the Changelog**
   - Check what changed
   - Note any breaking changes
   - Check compatibility notes

2. **Backup Your Saves**
   - Always backup before updating

3. **Remove Old Version**
   - Disable mod in BG3 Mod Manager
   - Delete old `.pak` file from Mods folder

4. **Install New Version**
   - Follow installation steps above
   - Use same method as original installation

5. **Test in Game**
   - Load a save
   - Check if existing items still work
   - Test new features

### Mid-Playthrough Updates

- Generally safe for minor updates
- Major updates may require new playthrough
- Check Nexus description for save compatibility

## Uninstallation

### To Remove the Mod

1. **In BG3 Mod Manager**
   - Uncheck "EldertideArmament"
   - Save load order
   - Close mod manager

2. **Remove Files**
   - Delete `.pak` file from Mods folder
   - Keep backup if you might reinstall

3. **Clean Save (Optional)**
   - Load save without mod
   - Drop all Eldertide items from inventory
   - Save game
   - Items will become unavailable

### Important Notes

- Items equipped when uninstalling may cause issues
- Drop all mod items before uninstalling
- Spells from items will be removed
- Some save files may have references that cause harmless errors

## Getting Help

### If You're Still Having Issues

1. **Check README.md** - Common issues and solutions
2. **Visit Nexus Posts Tab** - Community discussions
3. **Report Bugs** - Use format in CONTRIBUTING.md
4. **Search Existing Posts** - Your issue may be solved already

### Information to Include When Asking for Help

- Game version (e.g., Patch 8)
- Mod version (check meta.lsx)
- Installation method used
- Other mods installed (and load order)
- Exact error message or behavior
- Screenshots if applicable
- Steps you've already tried

---

*For additional support, visit the [Nexus Mods page](https://www.nexusmods.com/baldursgate3/mods/3596)*
