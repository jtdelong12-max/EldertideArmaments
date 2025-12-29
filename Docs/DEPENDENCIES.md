# Dependencies

This document outlines all dependencies and references used in the Eldertide Armaments mod.

## Required Dependencies

### BG3-Reference (jtdelong12-max/BG3-Reference)
**Status**: Required for development, reference only (not runtime dependency)

**Purpose**:
- Vanilla BG3 data validation
- RootTemplate UUID references
- Base weapon and armor type definitions (`using` statements)
- Status effect patterns and spell structures
- Ensures mod compatibility with base game

**Usage**:
- Reference files located in `reference/vanilla_data/`
- Provides examples of valid stat formats
- Used for `using` statements in Weapon.txt and Armor.txt
- Example: `using "WPN_Longsword_1"` references vanilla longsword base

**Files Referenced**:
- `reference/vanilla_data/Gustav/Stats/Generated/Data/Weapon.txt`
- `reference/vanilla_data/Gustav/Stats/Generated/Data/Armor.txt`
- `reference/vanilla_data/Gustav/Stats/Generated/Data/Status_BOOST.txt`
- `reference/vanilla_data/Gustav/Stats/Generated/Data/Passive.txt`
- `reference/vanilla_data/REFERENCE_Spells.txt`
- `reference/vanilla_data/REFERENCE_Status.txt`

## Build Tools

### Norbyte/lslib
**Status**: Required for packaging

**Purpose**:
- PAK file packaging for BG3 mod distribution
- GR2 model conversion (if custom models added)
- LSX/LSF file format conversion
- Data extraction from vanilla game files

**Version**: Latest stable release (7.x or higher recommended)

**Usage**: See BUILD.md for detailed instructions

**Download**: https://github.com/Norbyte/lslib/releases

## Optional Dependencies

### BG3-Community-Library
**Status**: Optional enhancement

**Purpose**:
- Enhanced icon library
- Class tags for better item filtering in-game
- Community-maintained item patterns
- Additional helper functions

**Integration**:
- Mod works fully without this dependency
- If present, enhanced features automatically enabled
- Provides better item categorization
- Improves compatibility with other community mods

**Note**: Not required for core functionality. Items will work with or without this library.

## Reference Only (Not Runtime)

### bg3se (jtdelong12-max/bg3se)
**Status**: Reference for patterns, not a runtime dependency

**Purpose**:
- API pattern validation for Lua scripting
- Console command testing during development
- Future scripting reference

**Usage**:
- Used during development for testing
- Not required for players
- May be used for future Lua-based features
- Provides examples of proper API usage

**Note**: While BG3 Script Extender enhances BG3 modding in general, Eldertide Armaments does not require it for normal operation.

## Asset Sources

### Custom Models from roaring_forge_intro_pack

The following custom weapon models are reused from the roaring_forge_intro_pack:

| Asset Name | RootTemplate UUID | Used For |
|------------|-------------------|----------|
| DreamshadowScythe | `4a47bd53-5a81-46ee-9ebf-6adbcb3194d2` | Death's Dominion Scythe |
| TheSilence | `23c9801d-d1bd-49ad-931f-29f569ef38f7` | Predator Shortsword |
| TidecallersMace | `c6a64ee9-7f66-4466-800e-cf23c2f5ca2f` | Frostbound Mace |
| ReineDesDiaments | `6867d0db-461f-485b-8562-aca3f517a0c6` | Dragonsoul Glaive |
| KuroHasuNodachi | `2266a9ac-1525-4b6e-872f-4db1cec16ef5` | Predator Nodachi |

These models provide unique visual appearances for key weapons in the expansion.

### Vanilla RootTemplates

All other items use appropriate vanilla BG3 RootTemplates to ensure compatibility and reduce mod size. These are referenced from the base game's RootTemplates and do not require additional assets.

## Player Requirements

### Minimum Requirements
- **Baldur's Gate 3**: Patch 8 (Build 4.1.1.6758295) or later
- **BG3 Mod Manager**: Recommended for installation
- **BG3 Mod Fixer**: Highly recommended for compatibility

### Optional Enhancements
- **Tutorial Chest Summoning**: For tutorial chest version
- **BG3 Script Extender**: Not required, but enhances overall modding experience

## Version Compatibility

### Game Version
- **Minimum**: Patch 8 (4.1.1.6758295)
- **Tested**: Patch 8 and later
- **Breaking Changes**: Version 1.6.4 and earlier are incompatible with Patch 8

### Mod Compatibility
This mod is designed to be compatible with:
- Equipment and armor mods (uses standard stat formats)
- Class overhaul mods (passive-based system)
- Visual enhancement mods
- Quality of life mods

**Potential Conflicts**:
- Mods that heavily modify treasure tables
- Mods that replace base weapon types
- Mods that override Equipment.txt completely

Use BG3 Mod Fixer to resolve most compatibility issues.

## Development Dependencies

For modders extending or modifying this mod:

### Python (3.8+)
- Validation scripts in `reference/scripts/`
- `validate_spells.py`, `validate_items.py`, `validate_references.py`

### Git
- Version control and collaboration
- Branch management for features

### Text Editor with BG3 Syntax
- VS Code with BG3 extensions recommended
- Syntax highlighting for .txt stat files
- LSX/XML editing support

## License & Attribution

### BG3-Reference
- Extracted vanilla game data for reference
- Used under fair use for modding purposes

### lslib (Norbyte)
- Open source tool for BG3 modding
- Used under its open source license

### Roaring Forge Models
- Custom models reused with permission
- Original creator attribution maintained

## Support & Resources

- **Nexus Mods Page**: https://www.nexusmods.com/baldursgate3/mods/3596
- **BG3 Modding Wiki**: https://wiki.bg3.community/
- **lslib Documentation**: https://github.com/Norbyte/lslib/wiki
- **Community Discord**: BG3 Modding Community

## Changelog

### Major Dependency Updates
- **v1.6.6**: Updated for Patch 8 compatibility
- **v1.6.5**: Added BG3 Mod Fixer as recommended dependency
- **v1.0.0**: Initial release with BG3-Reference integration

---

*For build instructions, see BUILD.md*
*For item details, see ITEMS.md*
