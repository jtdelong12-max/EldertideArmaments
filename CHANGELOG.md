# Changelog

All notable changes to Eldertide Armaments will be documented in this file.

## [1.6.4] - 2025-12-24

### Fixed
- Updated for BG3 Hotfix #35 (4.1.1.6995620) compatibility
- Fixed Hellfire Pact UI corruption in temporary camps by changing summon stack system
- Fixed Astral Champion's Ring manual dismissal freeze by preventing manual dismissal
- Fixed typos in Judgment Bolt and Quen spell descriptions

### Changed
- Hellfire Pact summons now use CONJURE_ELEMENTAL_STACK to prevent UI persistence bugs
- Astral Champion's Ring (Ethereal Alliance) summons can no longer be manually dismissed and expire at short rest to prevent freeze bug
- Updated mod version to 36873228391546881

## [Unreleased]

### Added
- Comprehensive README.md with installation instructions and troubleshooting
- CHANGELOG.md for tracking version history
- .gitignore for better repository management

### Fixed
- Duplicate entries in data files (previous PR)
- Redundant inheritance in stats files (previous PR)
- Syntax errors in BG3 mod data files (previous PR)

## [1.6.3] - Current Release

### Added
- 22 unique rings and amulets with custom spells and abilities
- 16 unique potions and elixirs
- Custom VFX from Vlad's Grimoire
- Journal pages and lore books
- Immersive world loot distribution across ~40 locations
- Tutorial chest version as alternative

### Features
- 13 legendary rings with powerful passive abilities
- 9 unique amulets with distinctive magical properties
- Each item provides unique spells unlocked on equip
- Items distributed across merchant inventories, treasure chests, and special locations
- Integration with Acts 1-3 loot tables

### Balance
- Items designed for endgame legendary tier
- Each item is unique and drops only once per playthrough (immersive version)
- Power level suitable for challenging endgame content
- Build-defining abilities that support diverse playstyles

### Known Issues
- RNG-based spawning may require checking multiple locations/vendors
- Some users report occasional duplicate drops in heavily modded setups
- Requires BG3 Mod Fixer for best compatibility with other mods

## Version History

### How to Check Your Version
The version number can be found in `Mods/EldertideArmament/meta.lsx`:
- Current Version attribute: `36873228391546880` (encoded as int64)
- This corresponds to version 1.6.3+

### Future Plans
- Continued compatibility updates with BG3 patches
- Community feedback integration
- Potential new items based on user requests
- Balance adjustments based on feedback

---

*For detailed information about each version's changes, check the Nexus Mods page changelog section.*
