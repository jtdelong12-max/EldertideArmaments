# BG3 Reference Files

**⚠️ IMPORTANT: These files are NOT part of the Eldertide Armaments mod!**

These are reference files extracted from Baldur's Gate 3 for development purposes only. 

## Purpose
- Validate custom weapon/armor/status IDs don't conflict with vanilla game
- Reference weapon stat templates and properties
- Ensure custom passives match BG3 standards
- Track BG3 version compatibility

## Source
Extracted from: **Baldur's Gate 3 Patch 8, Hotfix 35**
- Version Number: 4.1.1.6995620
- Release Date: December 2024
- Source: https://forums.larian.com/ubbthreads.php?ubb=showflat&Number=959320

Tools used:
- BG3 Modder's Multitool (https://github.com/ShinyHobo/BG3-Modders-Multitool)
- LSLib (https://github.com/Norbyte/lslib)

## Directory Structure

### vanilla/Data/Gustav/Stats/Generated/Data/
Reference files extracted from base game:
- `Weapon.txt` - All vanilla weapon definitions
- `Armor.txt` - All vanilla armor definitions
- `Status_BOOST.txt` - All vanilla status definitions
- `Passive.txt` - All vanilla passive definitions
- `Object.txt` - Item templates

### apis/
API documentation and reference:
- `Osiris_Functions.md` - Documented Osiris functions (Osi.*)
- `ScriptExtender_API.md` - Script Extender API reference (Ext.*)

## How to Use

### 1. Extract Reference Files
Use BG3 Modder's Multitool to extract from `Gustav.pak` and `Shared.pak`:
```
Data/Generated/Public/Shared/Stats/Generated/Data/Weapon.txt
Data/Generated/Public/Shared/Stats/Generated/Data/Armor.txt
Data/Generated/Public/Shared/Stats/Generated/Data/Status_BOOST.txt
Data/Generated/Public/Shared/Stats/Generated/Data/Passive.txt
Data/Generated/Public/Shared/Stats/Generated/Data/Object.txt
```

### 2. Validate Your Mod
See [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) for step-by-step validation instructions.

### 3. Update on BG3 Patches
When BG3 updates:
1. Update `version.txt` with new version number
2. Re-extract reference files from new PAK files
3. Run validation checks against updated files
4. Update mod code if conflicts are found

## Naming Conventions
All custom IDs in this mod should use the prefix `ET_` (Eldertide) to avoid conflicts:
- Example: `ET_Riptide_Sword`
- Example: `ET_TidalWave_Status`
- Example: `ET_SeaforgedArmor_Passive`

## License
These files are property of Larian Studios and included for reference only.
**Do not redistribute outside this repository.**

## Last Updated
2025-12-27 - Patch 8, Hotfix 35 (v4.1.1.6995620)
