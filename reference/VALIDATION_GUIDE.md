# Validation Guide - Eldertide Armaments

This guide explains how to validate your custom weapons, armor, and abilities against Baldur's Gate 3 game data.

## Overview

The validation system checks custom content against actual data files extracted from BG3. This ensures that:
- Custom weapon/armor IDs don't conflict with vanilla items
- Status effects reference valid game properties
- Passive abilities follow game standards
- Item stats are within acceptable ranges

## File Structure

All reference files follow the Gustav PAK directory structure:

```
reference/vanilla/Data/Gustav/Stats/Generated/Data/
├── Weapon.txt
├── Armor.txt
├── Status_BOOST.txt
├── Passive.txt
├── Object.txt
└── [other game data files]
```

## Extracting Game Data

To extract the latest game data from Baldur's Gate 3:

1. **Locate the Gustav PAK file** in your BG3 installation:
   - Typically found in: `Baldur's Gate 3/Data/Gustav.pak`

2. **Extract using the BG3 Modding Tools**:
   - Use the LSLib/Divine tool (https://github.com/Norbyte/lslib)
   - Extract the Gustav.pak maintaining the directory structure
   - Navigate to: `Data/Gustav/Stats/Generated/Data/`

3. **Copy the extracted files** to your reference directory:
   ```bash
   cp -r "extracted/Data/Gustav/Stats/Generated/Data/" reference/vanilla/Data/Gustav/Stats/Generated/Data/
   ```

## Validation Files

### Weapons (Weapon.txt)
- **Location**: `reference/vanilla/Data/Gustav/Stats/Generated/Data/Weapon.txt`
- **Purpose**: Validates weapon stat properties and ensures no ID conflicts
- **Key Properties**: Damage, WeaponRange, Proficiency Group, WeaponProperties

### Armor (Armor.txt)
- **Location**: `reference/vanilla/Data/Gustav/Stats/Generated/Data/Armor.txt`
- **Purpose**: Validates armor stats and equipment slots
- **Key Properties**: ArmorClass, Armor Type, Proficiency, Passives

### Status Effects (Status_BOOST.txt)
- **Location**: `reference/vanilla/Data/Gustav/Stats/Generated/Data/Status_BOOST.txt`
- **Purpose**: Validates status effect references in weapons/armor
- **Format**: Contains all valid status boost IDs from the game

### Passives (Passive.txt)
- **Location**: `reference/vanilla/Data/Gustav/Stats/Generated/Data/Passive.txt`
- **Purpose**: Validates passive ability references on items
- **Format**: Contains all passive ability definitions

### Objects (Object.txt)
- **Location**: `reference/vanilla/Data/Gustav/Stats/Generated/Data/Object.txt`
- **Purpose**: Validates treasure/chest templates
- **Format**: Container and item spawn definitions

## Validation Commands

### Check for Weapon ID Conflicts
```bash
# Check if custom weapon ID already exists
grep "ET_YourWeaponName" reference/vanilla/Data/Gustav/Stats/Generated/Data/Weapon.txt
# Empty output = safe to use
```

### Check for Armor ID Conflicts
```bash
grep "ET_YourArmorName" reference/vanilla/Data/Gustav/Stats/Generated/Data/Armor.txt
```

### Validate Status Effect Usage
```bash
# Check if status effect exists in vanilla
grep "YOUR_STATUS_NAME" reference/vanilla/Data/Gustav/Stats/Generated/Data/Status_BOOST.txt
```

### Validate Passive References
```bash
grep "YOUR_PASSIVE_NAME" reference/vanilla/Data/Gustav/Stats/Generated/Data/Passive.txt
```

## Common Validation Errors

### Invalid Weapon Property
```
Error: WeaponProperty "CustomProperty" not recognized
Fix: Use only vanilla weapon properties or define custom ones properly
```

### Conflicting Item ID
```
Error: Weapon ID "Shortsword" already exists in Weapon.txt
Fix: Use the ET_ prefix: "ET_Shortsword_Variant"
```

### Invalid Status Reference
```
Error: Status "CUSTOM_BUFF" not found in Status_BOOST.txt
Fix: Ensure custom status is defined in your mod's Statuses.txt
```

### Missing Passive Definition
```
Error: Passive "UnknownPassive" referenced but not defined
Fix: Verify passive exists in vanilla or define it in your PassiveData
```

## Best Practices

1. **Always Use the ET_ Prefix**
   - All custom IDs should start with `ET_`
   - Example: `ET_Riptide`, `ET_TidalArmor`

2. **Keep Reference Files Updated**
   - Re-extract game data after major BG3 patches
   - Update `version.txt` with current game version

3. **Use Exact Property Names**
   - Game properties are case-sensitive
   - Copy from reference files to avoid typos

4. **Validate Before Testing**
   - Run validation commands before packing your mod
   - Fix conflicts early to avoid in-game crashes

5. **Document Custom Content**
   - Mark custom statuses/passives clearly
   - Maintain CHANGELOG.md with all additions

## Troubleshooting

### Files Not Found
- Verify directory structure matches: `reference/vanilla/Data/Gustav/Stats/Generated/Data/`
- Check file permissions
- Ensure files were extracted properly from Gustav.pak

### Validation False Positives
- Check for trailing/leading whitespace in IDs
- Verify UTF-8 encoding (not UTF-16)
- Look for hidden characters

### Game Crashes After Adding Item
- Validate all referenced statuses exist
- Check that damage/AC values are reasonable
- Ensure WeaponProperties are comma-separated with no spaces

## Additional Resources

- [BG3 Modding Wiki](https://bg3.wiki)
- [LSLib Documentation](https://github.com/Norbyte/lslib)
- [BG3 Modding Community Discord](https://discord.gg/bg3modding)
- [Weapon Properties Reference](https://bg3.wiki/wiki/Weapon_Properties)
