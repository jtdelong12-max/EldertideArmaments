# Changelog

All notable changes to Eldertide Armaments will be documented in this file.

## [2.0.0] - 2025-12-30

### MAJOR CHANGES - Mod Simplification
- **BREAKING CHANGE:** Removed all weapon and armor equipment sets (70+ items)
- Mod now focuses exclusively on rings, amulets, and consumable potions
- This simplification reduces complexity and potential balance issues

### Removed
- **Weapons:** All 18 equipment set weapons removed (ELDR_WPN_* entries)
  - Stormlord, Dragonsoul, Death's Dominion, Phoenix Soul, Predator, Frostbound, Witcher, Mindwarden, Bloodsworn, and Avernus sets
- **Armor:** All 55+ armor pieces removed (ELDR_ARM_* entries)
  - Helmets, body armor, gloves, boots, shields, and cloaks from all 10 sets
- **Passives:** All equipment set bonus passives removed (ELDR_PAS_* entries)
  - Set bonus trackers, signature mechanics, and amplifier passives
- **Spells:** All equipment-specific spells removed
  - 12 Rush attacks (Rush_ELDR_*)
  - 12 Zone attacks (Zone_ELDR_*)
  - 10 Shout abilities (Shout_ELDR_*)
  - Equipment-specific target spells
  - 2 Interrupt reactions (Shadow Vanish, Parry)

### Kept (Unchanged)
- **13 Legendary Rings** - All ring abilities and passives preserved
- **9 Powerful Amulets** - All amulet abilities and passives preserved
- **16 Consumable Potions** - All consumables remain available
- **Journal Pages and Books** - Lore items preserved
- **NPC Equipment** - Minthara, Nere, and other NPC gear untouched

### Documentation Updates
- Updated README.md to reflect rings/amulets/potions focus
- Updated ITEMS.md - removed 270+ lines of equipment set documentation
- Rewrote Docs/IMPLEMENTATION_SUMMARY.md to focus on rings/amulets/potions
- Updated this CHANGELOG.md to document removal

### Migration Notes
- **Existing saves:** If you have equipment set items equipped, they will be removed upon loading
- **Recommendation:** Start a new game or load a save from before using equipment sets
- This is a major version change (2.0.0) due to breaking compatibility

## [1.6.6] - 2025-12-25

### Performance Improvements
- **MAJOR OPTIMIZATION:** Removed 83 lines of redundant code for improved loading times and reduced memory footprint
- Removed 25 redundant MemoryCost declarations from item-granted spells (only needed for memorizable wizard spells)
- Removed 51 unnecessary empty property declarations across all stat files:
  - Empty Cooldown, SpellContainerID, ContainerSpells declarations
  - Empty ExtraDescription, SpellFail, TooltipDamageList, TooltipOnSave declarations
  - Empty PassivesOnEquip, ItemGroup, ProficiencyBonus declarations
  - Empty resistance property declarations
- Cleaned up code structure for better maintainability

### Changed
- Optimized data files reduce mod parsing time during game startup
- Improved compatibility with BG3 Patch 8 modding standards

## [1.6.5] - 2025-12-24

### Fixed
- **CRITICAL:** Updated for BG3 Patch 8 (4.1.1.6758295) compatibility - fixes 85% loading freeze
- Fixed empty UseCosts on ELDER_Shout_WrathOfAvernus causing potential loading failures
- Cleaned up redundant MemoryCost declarations (22 instances removed - note: this was incomplete, fully resolved in 1.6.6)

### Changed
- Game version requirement: Now requires BG3 Patch 8 (April 2025 update)
- Improved spell definition standards for better compatibility
- Updated mod version to 36873228391546882

### Known Issues
- If upgrading from v1.6.4 or earlier, you may need to start a new game or load a save from before the mod was installed

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
