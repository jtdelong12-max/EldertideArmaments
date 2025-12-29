# Build Guide

This document provides instructions for building and packaging the Eldertide Armaments mod using lslib.

## Prerequisites

### Required Tools

1. **lslib (LSLib Toolkit)**
   - Download: https://github.com/Norbyte/lslib/releases
   - Version: 7.x or higher recommended
   - Extract to a convenient location (e.g., `C:\Tools\lslib\`)

2. **Baldur's Gate 3**
   - Patch 8 (4.1.1.6758295) or later
   - Access to game installation directory

3. **Text Editor**
   - VS Code, Notepad++, or similar
   - BG3 syntax highlighting recommended

### Optional Tools

- **Git**: For version control
- **Python 3.8+**: For validation scripts
- **BG3 Mod Manager**: For testing installations

## Project Structure

```
EldertideArmaments/
├── Public/
│   └── EldertideArmament/
│       ├── Stats/Generated/
│       │   ├── Data/
│       │   │   ├── Weapon.txt
│       │   │   ├── Armor.txt
│       │   │   ├── Passive_Eldertide.txt
│       │   │   ├── Status_Eldertide.txt
│       │   │   ├── Spells_Eldertide_Main.txt
│       │   │   ├── Spell_Rush.txt
│       │   │   ├── Spell_Zone.txt
│       │   │   ├── Spell_Target.txt
│       │   │   ├── Spell_Shout.txt
│       │   │   └── Interrupt.txt
│       │   ├── Equipment.txt
│       │   └── TreasureTable.txt
│       ├── RootTemplates/
│       │   └── _merged.lsf.lsx
│       ├── GUI/
│       │   └── Icons_EldertideArmament.lsx
│       └── Localization/
│           └── English/
│               └── __MT_GEN_LOCA_*.loca.xml
├── Mods/
│   └── EldertideArmament/
│       └── meta.lsx
└── Localization/
    └── English/
        └── __MT_GEN_LOCA_*.loca.xml
```

## Building the Mod

### Step 1: Prepare Source Files

1. Ensure all stat files are properly formatted
2. Validate references between files
3. Check localization entries exist for all new content

**Validation Commands** (if using Python scripts):
```bash
# Validate spells
python3 reference/scripts/validate_spells.py Public/EldertideArmament/Stats/Generated/Data/

# Validate items
python3 reference/scripts/validate_items.py Public/EldertideArmament/Stats/Generated/Data/Armor.txt

# Validate weapon entries
python3 reference/scripts/validate_items.py Public/EldertideArmament/Stats/Generated/Data/Weapon.txt

# Check all cross-references
python3 reference/scripts/validate_references.py Public/EldertideArmament/
```

### Step 2: Update meta.lsx

Edit `Mods/EldertideArmament/meta.lsx` to update version information:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<save>
    <version major="4" minor="0" revision="9" build="328"/>
    <region id="Config">
        <node id="root">
            <children>
                <node id="ModuleInfo">
                    <attribute id="Author" type="LSString" value="Proxeuz"/>
                    <attribute id="Name" type="LSString" value="EldertideArmament"/>
                    <attribute id="Folder" type="LSString" value="EldertideArmament"/>
                    <attribute id="UUID" type="FixedString" value="22b848d1-5fff-4f76-a4f8-8461721e6112"/>
                    <attribute id="Version64" type="int64" value="36028797018963968"/>
                    <attribute id="Description" type="LSString" value="Comprehensive magical equipment expansion"/>
                    <attribute id="Type" type="FixedString" value="Add-on"/>
                </node>
            </children>
        </node>
    </region>
</save>
```

**Version Number** is encoded as `int64`:
- Format: `Major.Minor.Revision.Build`
- Example: `1.6.7.0` → `36028797018963968`
- Use lslib or online calculators to convert

### Step 3: Package with lslib

#### Using Divine GUI (Recommended for Beginners)

1. **Launch Divine.exe** from lslib installation

2. **Select "Package" Tab**

3. **Configure Package Settings:**
   - **Source Path**: Browse to your mod's root directory (containing `Public/` and `Mods/`)
   - **Destination Path**: Choose output location for `.pak` file
   - **Package Name**: `EldertideArmament.pak`
   - **Package Version**: Select `v18` (for BG3 Patch 8+)

4. **Packaging Options:**
   - ✅ Compress packages
   - ✅ Compress solid archives (recommended for smaller file size)
   - ✅ Fast compression (faster, slightly larger) OR
   - ⬜ Fast compression (unchecked for maximum compression)

5. **Click "Create Package"**

6. **Verify Output:**
   - Check destination folder for `EldertideArmament.pak`
   - File size should be reasonable (expect 1-5 MB depending on assets)

#### Using Divine CLI (Advanced)

```bash
# Basic packaging
Divine.exe -g bg3 -s "C:\Path\To\EldertideArmaments" -d "C:\Output\EldertideArmament.pak" -a create-package -c zlib -p v18

# With compression options
Divine.exe -g bg3 -s "C:\Path\To\EldertideArmaments" -d "C:\Output\EldertideArmament.pak" -a create-package -c zlib -p v18 --compression-level max

# Arguments explained:
# -g bg3           : Target game (Baldur's Gate 3)
# -s <source>      : Source directory path
# -d <destination> : Destination .pak file path
# -a create-package: Action to perform
# -c zlib          : Compression method
# -p v18           : Package version (BG3 Patch 8+)
# --compression-level: max|fast|normal
```

### Step 4: Test Installation

1. **Copy PAK file** to:
   ```
   %LocalAppData%\Larian Studios\Baldur's Gate 3\Mods\
   ```

2. **Use BG3 Mod Manager:**
   - Open BG3 Mod Manager
   - Refresh mod list
   - Enable "EldertideArmament"
   - Export load order

3. **Manual Installation** (Alternative):
   - Edit `modsettings.lsx` in:
     ```
     %LocalAppData%\Larian Studios\Baldur's Gate 3\PlayerProfiles\<profile>\
     ```
   - Add mod UUID: `22b848d1-5fff-4f76-a4f8-8461721e6112`

4. **Launch Game and Test:**
   - Start new game or load save
   - Use console (if bg3se installed) or tutorial chest to verify items
   - Check for errors in game log

## Common Build Issues

### Issue: "Package creation failed"

**Causes:**
- Invalid XML/LSX syntax in files
- Missing required files
- Incorrect folder structure

**Solutions:**
- Validate all XML files with XML linter
- Ensure meta.lsx is properly formatted
- Check folder structure matches expected layout
- Review Divine error messages for specific file

### Issue: "Items not appearing in game"

**Causes:**
- Incorrect RootTemplate UUIDs
- Missing localization entries
- TreasureTable not properly configured

**Solutions:**
- Verify RootTemplate UUIDs exist in game or custom RootTemplates
- Check all items have localization entries
- Validate TreasureTable.txt syntax
- Test with tutorial chest version first

### Issue: "Game crashes on load"

**Causes:**
- Invalid stat references
- Circular dependencies in boosts/passives
- Malformed spell definitions

**Solutions:**
- Use validation scripts to check references
- Review game log for specific error
- Test with minimal stat definitions first
- Remove recently added content to isolate issue

### Issue: "Package too large"

**Causes:**
- Unnecessary files included
- Uncompressed assets
- Duplicate textures/models

**Solutions:**
- Use maximum compression in lslib
- Remove development files (.git, temp files)
- Reuse vanilla assets where possible
- Compress textures to DDS format

## File Format Conversions

### LSX ↔ LSF Conversion

lslib can convert between human-readable LSX and binary LSF formats:

```bash
# LSF to LSX (for editing)
Divine.exe -s input.lsf.lsx -d output.lsx -a convert-lsx

# LSX to LSF (for packaging)
Divine.exe -s input.lsx -d output.lsf.lsx -a convert-lsx
```

**Note**: Most files should remain as `.lsx` for modding. Only convert to `.lsf` if specifically required by game.

### GR2 Model Conversion

If adding custom weapon models:

```bash
# Extract GR2 to Collada
Divine.exe -s model.gr2 -d model.dae -a convert-model

# Collada to GR2 (after editing)
Divine.exe -s model.dae -d model.gr2 -a convert-model --conform divine-gr2
```

**Requirements:**
- GR2 SDK (for advanced conversions)
- Blender with GR2 plugin (for model editing)

## Automated Build Scripts

### Windows Batch Script

Create `build.bat`:

```batch
@echo off
echo Building Eldertide Armaments...

REM Set paths
set LSLIB="C:\Tools\lslib\Divine.exe"
set SOURCE=%~dp0
set OUTPUT="%~dp0build\EldertideArmament.pak"

REM Create build directory
if not exist "%~dp0build" mkdir "%~dp0build"

REM Package mod
%LSLIB% -g bg3 -s "%SOURCE%" -d %OUTPUT% -a create-package -c zlib -p v18 --compression-level max

echo Build complete! Package created at %OUTPUT%
pause
```

### Linux/Mac Shell Script

Create `build.sh`:

```bash
#!/bin/bash
echo "Building Eldertide Armaments..."

# Set paths
DIVINE="/path/to/Divine.exe"
SOURCE="$(dirname "$0")"
OUTPUT="$SOURCE/build/EldertideArmament.pak"

# Create build directory
mkdir -p "$SOURCE/build"

# Package mod (use mono on Linux/Mac)
mono "$DIVINE" -g bg3 -s "$SOURCE" -d "$OUTPUT" -a create-package -c zlib -p v18 --compression-level max

echo "Build complete! Package created at $OUTPUT"
```

Make executable:
```bash
chmod +x build.sh
```

## Distribution

### For Nexus Mods Upload

1. **Create ZIP archive** containing:
   - `EldertideArmament.pak`
   - `README.txt` (installation instructions)
   - `CHANGELOG.txt`

2. **Naming Convention:**
   - `EldertideArmament_v1.6.7.zip` (version number)
   - `EldertideArmament_TutorialChest_v1.6.7.zip` (variant)

3. **File Description:**
   - Clear version number
   - Compatible game version
   - Required dependencies
   - Installation method

### Version Control

Tag releases in Git:
```bash
git tag -a v1.6.7 -m "Version 1.6.7 - Major expansion with 70+ new items"
git push origin v1.6.7
```

## Performance Optimization

### Reducing Load Times

1. **Minimize File Size:**
   - Use maximum compression
   - Remove unused entries from stat files
   - Optimize texture sizes

2. **Efficient Stat Definitions:**
   - Reuse vanilla stats with `using` statements
   - Avoid redundant boost definitions
   - Group similar items

3. **Localization:**
   - Only include required languages
   - Remove duplicate entries
   - Use contentuid efficiently

### Memory Optimization

- Keep RootTemplates lean
- Reuse vanilla models where possible
- Limit custom textures
- Test on minimum spec systems

## Continuous Integration

For automated builds in CI/CD:

```yaml
# GitHub Actions example
name: Build Mod
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install lslib
        run: |
          wget https://github.com/Norbyte/lslib/releases/latest/download/lslib.zip
          unzip lslib.zip -d lslib
      - name: Build PAK
        run: |
          mono lslib/Divine.exe -g bg3 -s . -d build/EldertideArmament.pak -a create-package -c zlib -p v18
      - name: Upload Artifact
        uses: actions/upload-artifact@v2
        with:
          name: EldertideArmament
          path: build/EldertideArmament.pak
```

## Additional Resources

- **lslib Documentation**: https://github.com/Norbyte/lslib/wiki
- **BG3 Modding Wiki**: https://wiki.bg3.community/
- **BG3 Modding Discord**: Community support
- **Nexus Mods Forums**: User support and feedback

---

*For dependency information, see DEPENDENCIES.md*
*For item details, see ITEMS.md*
