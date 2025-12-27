# Validation Guide for Eldertide Armaments

## Overview

This validation guide helps ensure that mod files follow Baldur's Gate 3 conventions and are compatible with the vanilla game data structure. By validating your files against these references, you can catch errors early and ensure compatibility with BG3 Patch 8 and beyond.

## Purpose

The reference and validation structure in this repository serves to:

1. **Provide vanilla BG3 data examples** - Reference files showing proper syntax and structure
2. **Validate custom content** - Scripts to check your mod files against BG3 standards
3. **Prevent common errors** - Catch issues before they cause in-game problems
4. **Maintain compatibility** - Ensure mod updates remain compatible with BG3 patches
5. **Document best practices** - Share knowledge about BG3 modding conventions

## Directory Structure

```
reference/
├── README.md                          # This file
├── vanilla_data/                      # BG3 vanilla reference data
│   ├── spells/
│   │   └── REFERENCE_Spells.txt       # Spell definition examples
│   ├── items/
│   │   └── REFERENCE_Items.txt        # Item/armor definition examples
│   ├── status_effects/
│   │   └── REFERENCE_Status.txt       # Status effect examples
│   └── passives/
│       └── REFERENCE_Passives.txt     # Passive ability examples
└── scripts/
    ├── validate_spells.py             # Spell validation script
    ├── validate_items.py              # Item validation script
    └── validate_references.py         # Cross-reference validation
```

## How to Use This Guide

### 1. Understanding Reference Files

Each reference file in `vanilla_data/` contains:
- **Real vanilla BG3 examples** - Actual game data structures
- **Property documentation** - Explanation of valid values
- **Common patterns** - Frequently used combinations
- **Validation checklists** - What to verify before finalizing

**Example Usage:**
```bash
# View spell reference data
cat reference/vanilla_data/spells/REFERENCE_Spells.txt

# Search for specific spell types
grep "SpellType" reference/vanilla_data/spells/REFERENCE_Spells.txt
```

### 2. Validating Your Custom Content

#### Manual Validation

Compare your custom files against the reference files:

1. **Open your mod file** (e.g., `Public/EldertideArmament/Stats/Generated/Data/Spells_Eldertide_Main.txt`)
2. **Open the reference file** (`reference/vanilla_data/spells/REFERENCE_Spells.txt`)
3. **Check your entries** against the reference patterns
4. **Verify each property** exists in the reference and uses valid values

#### Automated Validation

Use the validation scripts to check your files:

```bash
# Validate spell definitions
python3 reference/scripts/validate_spells.py Public/EldertideArmament/Stats/Generated/Data/

# Validate item definitions
python3 reference/scripts/validate_items.py Public/EldertideArmament/Stats/Generated/Data/

# Check for broken cross-references
python3 reference/scripts/validate_references.py Public/EldertideArmament/
```

### 3. Common Validation Checks

#### Spells (REFERENCE_Spells.txt)

**Must verify:**
- ✓ `SpellType` is valid (Projectile, Target, Zone, Shout, etc.)
- ✓ `Level` is 0-9 (0 for cantrips)
- ✓ `SpellSchool` is one of the 8 schools
- ✓ `DamageType` matches BG3 damage types
- ✓ `SpellRoll` format is correct
- ✓ `UseCosts` follows proper syntax
- ✓ All referenced spells/statuses exist

**Example check:**
```bash
# Find all SpellType values in your mod
grep "data \"SpellType\"" Public/EldertideArmament/Stats/Generated/Data/Spells_*.txt

# Compare against valid types in reference
grep "// SpellType Options:" reference/vanilla_data/spells/REFERENCE_Spells.txt -A 10
```

#### Items (REFERENCE_Items.txt)

**Must verify:**
- ✓ `using` clause references valid base (_Ring, _Amulet, etc.)
- ✓ `RootTemplate` UUID is unique and valid format
- ✓ `ObjectCategory` matches item type
- ✓ `Rarity` is valid (Common, Uncommon, Rare, VeryRare, Legendary)
- ✓ `Boosts` use correct syntax with semicolon separators
- ✓ All referenced PassivesOnEquip exist
- ✓ All UnlockSpell() references exist

**Example check:**
```bash
# Check all rarity values
grep "data \"Rarity\"" Public/EldertideArmament/Stats/Generated/Data/Armor.txt

# Verify against valid rarities
grep "// Rarity Options:" reference/vanilla_data/items/REFERENCE_Items.txt -A 10
```

#### Status Effects (REFERENCE_Status.txt)

**Must verify:**
- ✓ `StatusType` is valid
- ✓ `StackId` is unique
- ✓ `TickType` is appropriate
- ✓ `Boosts` syntax is correct
- ✓ `OnApplyFunctors` are valid
- ✓ `StatusEffect` UUID is valid
- ✓ No infinite loops in status applications

**Example check:**
```bash
# Find all StatusType values
grep "data \"StatusType\"" Public/EldertideArmament/Stats/Generated/Data/Status_*.txt

# Check for duplicate StackIds
grep "data \"StackId\"" Public/EldertideArmament/Stats/Generated/Data/Status_*.txt | sort | uniq -d
```

#### Passives (REFERENCE_Passives.txt)

**Must verify:**
- ✓ `Properties` are valid
- ✓ `Boosts` syntax is correct
- ✓ `StatsFunctorContext` matches trigger timing
- ✓ `Conditions` are properly formatted
- ✓ No performance-heavy calculations
- ✓ All referenced statuses exist

**Example check:**
```bash
# Find all passive properties
grep "data \"Properties\"" Public/EldertideArmament/Stats/Generated/Data/Passive_*.txt

# Check StatsFunctorContext values
grep "data \"StatsFunctorContext\"" Public/EldertideArmament/Stats/Generated/Data/Passive_*.txt
```

## Validation Scripts

### validate_spells.py

Validates spell definitions against BG3 standards.

**Checks performed:**
- Valid SpellType values
- Correct Level range (0-9)
- Valid SpellSchool names
- Proper DamageType values
- Correct UseCosts format
- Valid SpellFlags combinations

**Usage:**
```bash
python3 reference/scripts/validate_spells.py Public/EldertideArmament/Stats/Generated/Data/
```

**Output:**
- Lists all validation errors
- Shows line numbers and file locations
- Suggests fixes for common issues

### validate_items.py

Validates item/armor definitions.

**Checks performed:**
- Valid using clause references
- UUID format validation
- Correct ObjectCategory values
- Valid Rarity values
- Proper Boosts syntax
- Ability score cap validation

**Usage:**
```bash
python3 reference/scripts/validate_items.py Public/EldertideArmament/Stats/Generated/Data/Armor.txt
```

**Output:**
- Reports syntax errors
- Identifies invalid property values
- Warns about unbalanced items

### validate_references.py

Checks for broken cross-references between files.

**Checks performed:**
- UnlockSpell() references valid spells
- PassivesOnEquip references valid passives
- StatusOnEquip references valid statuses
- ApplyStatus() calls reference valid statuses
- All RootTemplate UUIDs are unique

**Usage:**
```bash
python3 reference/scripts/validate_references.py Public/EldertideArmament/
```

**Output:**
- Lists missing references
- Shows where each reference is used
- Identifies UUID conflicts

## Best Practices

### Before Making Changes

1. **Backup your files** - Keep a working copy
2. **Review reference files** - Understand the patterns
3. **Check existing examples** - Look at similar vanilla content
4. **Plan your changes** - Know what you're modifying

### While Modifying

1. **Follow vanilla patterns** - Stay consistent with BG3 style
2. **Test incrementally** - Make small changes and test
3. **Comment your code** - Add notes for complex entries
4. **Use proper formatting** - Maintain consistent indentation

### After Changes

1. **Run validation scripts** - Catch errors early
2. **Test in-game** - Verify functionality
3. **Check for conflicts** - Ensure no mod conflicts
4. **Document changes** - Update CHANGELOG.md

## Common Errors and Solutions

### Error: Invalid SpellType

**Problem:** Using a SpellType that doesn't exist in BG3
```
data "SpellType" "Beam"  // WRONG - "Beam" is not valid
```

**Solution:** Use a valid SpellType from reference
```
data "SpellType" "Projectile"  // CORRECT
```

### Error: Incorrect Rarity Value

**Problem:** Typo or wrong rarity name
```
data "Rarity" "Epic"  // WRONG - "Epic" doesn't exist
```

**Solution:** Use proper BG3 rarity
```
data "Rarity" "Legendary"  // CORRECT
```

### Error: Malformed Boosts

**Problem:** Missing semicolons or incorrect syntax
```
data "Boosts" "Ability(Strength,2,20),AC(2)"  // WRONG - uses comma
```

**Solution:** Use semicolons to separate boosts
```
data "Boosts" "Ability(Strength,2,20);AC(2)"  // CORRECT
```

### Error: Broken Spell Reference

**Problem:** UnlockSpell references non-existent spell
```
data "Boosts" "UnlockSpell(ELDER_Fireball_Supreme)"  // Spell doesn't exist
```

**Solution:** Verify spell exists or create it first
```
// First define the spell in Spells_Eldertide_Main.txt
new entry "ELDER_Fireball_Supreme"
type "SpellData"
...

// Then reference it
data "Boosts" "UnlockSpell(ELDER_Fireball_Supreme)"  // Now valid
```

### Error: Duplicate StackId

**Problem:** Two statuses with same StackId
```
new entry "MY_STATUS_1"
data "StackId" "BURNING"  // Already used by vanilla

new entry "MY_STATUS_2"
data "StackId" "BURNING"  // Conflict!
```

**Solution:** Use unique StackIds with mod prefix
```
data "StackId" "ELDER_BURNING_1"  // Unique
data "StackId" "ELDER_BURNING_2"  // Also unique
```

### Error: Invalid UUID Format

**Problem:** Malformed UUID in RootTemplate
```
data "RootTemplate" "761aa984-3a34-4b21"  // Too short
```

**Solution:** Use complete UUID format
```
data "RootTemplate" "761aa984-3a34-4b21-a1ce-3adf917796ac"  // Correct
```

## Compatibility Testing

### Test with Vanilla BG3

1. **Clean install test** - Test with minimal mods
2. **Load order test** - Verify proper load order
3. **Compatibility test** - Test with popular mods
4. **Performance test** - Check for lag/stuttering

### Test Custom Content

1. **Item acquisition** - Verify items spawn correctly
2. **Spell casting** - Test all custom spells work
3. **Status effects** - Verify statuses apply/remove properly
4. **Passive abilities** - Confirm passives trigger correctly
5. **Visual effects** - Check VFX display properly

## Updating for New BG3 Patches

When a new BG3 patch releases:

1. **Check patch notes** - Look for data structure changes
2. **Update reference files** - Add new vanilla examples
3. **Re-validate mod** - Run all validation scripts
4. **Test in-game** - Verify everything still works
5. **Update documentation** - Note any changes needed

## Contributing to Reference Files

If you find errors or want to add examples:

1. **Verify accuracy** - Ensure examples are from vanilla BG3
2. **Follow format** - Match existing reference file style
3. **Add comments** - Explain complex entries
4. **Test examples** - Verify they work in-game
5. **Submit changes** - Create pull request or issue

## Resources

### Official Resources
- [BG3 Wiki - Modding Resources](https://bg3.wiki/wiki/Modding:Modding_resources)
- [Larian Studios Modding Documentation](https://docs.larian.game)
- [BG3 Mod Manager](https://github.com/LaughingLeader/BG3ModManager)

### Community Resources
- [BG3 Modding Discord](https://discord.gg/bg3mods)
- [Nexus Mods BG3 Forums](https://forums.nexusmods.com/index.php?/forum/5264-baldurs-gate-3/)
- [BG3 Modding Wiki](https://bg3.wiki)

### Tools
- [BG3 Script Extender](https://github.com/Norbyte/bg3se)
- [BG3 Mod Fixer](https://www.nexusmods.com/baldursgate3/mods/141)
- [LSLib Toolkit](https://github.com/Norbyte/lslib) - For advanced file manipulation

## Version History

### Version 1.0 (Current)
- Initial reference and validation guide structure
- Added vanilla reference files for spells, items, status effects, and passives
- Created validation scripts for automated checking
- Documented common errors and solutions
- Compatible with BG3 Patch 8 (Build 6758295)

## Support

If you encounter issues with validation:

1. **Check this guide** - Review relevant sections
2. **Check reference files** - Look for similar examples
3. **Run validation scripts** - Identify specific errors
4. **Search community** - Check forums and Discord
5. **Report issues** - Create GitHub issue with details

---

*This validation guide is maintained as part of the Eldertide Armaments mod project. For questions or contributions, see CONTRIBUTING.md*
