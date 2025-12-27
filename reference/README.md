# BG3 Reference Data and Validation Structure

## Overview

This directory contains reference data and validation tools for Baldur's Gate 3 modding. It provides vanilla game data examples and scripts to validate custom mod content against BG3 standards.

## Inspiration

This reference structure is inspired by the [AI-Allies](https://github.com/jtdelong12-max/AI-Allies) repository approach to organizing and validating Baldur's Gate 3 data. Similar to how AI-Allies organizes wiki knowledge for semantic search, this structure organizes vanilla game data for mod validation.

## Directory Structure

```
reference/
├── README.md                          # This file
├── vanilla_data/                      # BG3 vanilla reference data
│   ├── spells/
│   │   └── REFERENCE_Spells.txt       # Spell definition examples from vanilla BG3
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

## Purpose

This reference structure serves multiple purposes:

### 1. **Documentation**
- Provides real vanilla BG3 examples for modders
- Documents valid property values and syntax
- Shows common patterns and best practices

### 2. **Validation**
- Scripts to automatically check mod files
- Catch errors before in-game testing
- Verify cross-references between files

### 3. **Quality Assurance**
- Ensures consistency with BG3 standards
- Maintains compatibility with game patches
- Reduces bugs and conflicts

### 4. **Learning Resource**
- Helps new modders understand BG3 data structures
- Shows how vanilla content is structured
- Provides templates for custom content

## How to Use

### Quick Start

1. **View reference data:**
   ```bash
   # See spell examples
   cat reference/vanilla_data/spells/REFERENCE_Spells.txt
   
   # See item examples
   cat reference/vanilla_data/items/REFERENCE_Items.txt
   ```

2. **Validate your mod files:**
   ```bash
   # Validate spells
   python3 reference/scripts/validate_spells.py Public/EldertideArmament/Stats/Generated/Data/
   
   # Validate items
   python3 reference/scripts/validate_items.py Public/EldertideArmament/Stats/Generated/Data/Armor.txt
   
   # Check all cross-references
   python3 reference/scripts/validate_references.py Public/EldertideArmament/
   ```

3. **Read the full guide:**
   ```bash
   # Open the comprehensive validation guide
   cat VALIDATION_GUIDE.md
   ```

### Reference Files

Each reference file contains:

#### REFERENCE_Spells.txt
- Examples of Projectile, Target, Zone, and Shout spells
- Valid SpellType, SpellSchool, and DamageType values
- Proper UseCosts and SpellFlags formats
- Common spell properties and their values

#### REFERENCE_Items.txt
- Examples of rings, amulets, and armor
- Valid using clauses and base templates
- Boosts syntax and common combinations
- Rarity and ObjectCategory values

#### REFERENCE_Status.txt
- Examples of buff, debuff, and condition statuses
- TickType and StatusPropertyFlags options
- OnApplyFunctors, OnTickFunctors patterns
- Status immunity groups

#### REFERENCE_Passives.txt
- Examples of various passive ability types
- Properties and StatsFunctorContext values
- Common Boosts and Conditions
- Trigger timing and stacking rules

## Validation Scripts

### validate_spells.py

**Purpose:** Validates spell definitions against BG3 standards

**Features:**
- Checks valid SpellType values
- Verifies Level range (0-9)
- Validates SpellSchool names
- Confirms proper DamageType values
- Checks UseCosts format
- Validates SpellFlags combinations

**Usage:**
```bash
python3 reference/scripts/validate_spells.py <path_to_spell_files>
```

**Example Output:**
```
✓ Validated: ELDER_Projectile_SkywardSoar
✗ Error in ELDER_Zone_DragonkinHeritage: Invalid SpellType "Beam"
✗ Error in ELDER_Target_Lifesteal: Level 10 exceeds maximum (9)
```

### validate_items.py

**Purpose:** Validates item and armor definitions

**Features:**
- Checks valid using clause references
- Validates UUID format
- Verifies ObjectCategory values
- Confirms proper Rarity values
- Checks Boosts syntax
- Validates ability score caps

**Usage:**
```bash
python3 reference/scripts/validate_items.py <path_to_armor_files>
```

**Example Output:**
```
✓ Validated: ELDER_Ring_1
✗ Error in ELDER_Ring_2: Invalid Rarity "Epic"
✗ Warning in ELDER_Ring_3: Ability bonus exceeds recommended cap
```

### validate_references.py

**Purpose:** Checks for broken cross-references between files

**Features:**
- Validates UnlockSpell() references
- Checks PassivesOnEquip exist
- Verifies StatusOnEquip references
- Confirms ApplyStatus() targets exist
- Detects duplicate UUIDs

**Usage:**
```bash
python3 reference/scripts/validate_references.py <path_to_mod_directory>
```

**Example Output:**
```
✓ All spell references valid
✗ Missing passive: Passive_ELDER_DraconicRetaliation (referenced in ELDER_Ring_1)
✗ Missing status: ELDER_BURNING (referenced in ELDER_Spell_Fireball)
✗ Duplicate UUID found: 761aa984-3a34-4b21-a1ce-3adf917796ac
```

## Common Validation Patterns

### Checking Your Custom Spells

```bash
# 1. Compare against reference
diff -u reference/vanilla_data/spells/REFERENCE_Spells.txt \
        Public/EldertideArmament/Stats/Generated/Data/Spells_Eldertide_Main.txt

# 2. Check for invalid properties
grep "data \"SpellType\"" Public/EldertideArmament/Stats/Generated/Data/Spells_*.txt | \
  grep -v "Projectile\|Target\|Zone\|Shout\|Rush\|Wall\|Teleportation"

# 3. Run validation script
python3 reference/scripts/validate_spells.py Public/EldertideArmament/Stats/Generated/Data/
```

### Checking Your Custom Items

```bash
# 1. Check rarity values
grep "data \"Rarity\"" Public/EldertideArmament/Stats/Generated/Data/Armor.txt | \
  grep -v "Common\|Uncommon\|Rare\|VeryRare\|Legendary\|Divine\|Unique"

# 2. Check for malformed boosts (using commas instead of semicolons)
grep "data \"Boosts\"" Public/EldertideArmament/Stats/Generated/Data/Armor.txt | \
  grep -E "\),\w"

# 3. Run validation script
python3 reference/scripts/validate_items.py Public/EldertideArmament/Stats/Generated/Data/Armor.txt
```

### Checking Cross-References

```bash
# 1. Find all spell unlocks
grep -r "UnlockSpell(" Public/EldertideArmament/Stats/Generated/Data/

# 2. List all spell definitions
grep "^new entry" Public/EldertideArmament/Stats/Generated/Data/Spells_*.txt

# 3. Run comprehensive check
python3 reference/scripts/validate_references.py Public/EldertideArmament/
```

## Benefits

### For Development
- **Catch errors early** - Before in-game testing
- **Save time** - Automated validation vs manual checking
- **Improve quality** - Consistent standards enforcement
- **Reduce bugs** - Fewer syntax and reference errors

### For Maintenance
- **Track changes** - Version-controlled reference data
- **Document patterns** - Examples for future modifications
- **Enable updates** - Easy to update for new BG3 patches
- **Support community** - Help others understand the mod structure

### For Collaboration
- **Onboard contributors** - Clear examples and validation
- **Maintain consistency** - Shared standards and tools
- **Review changes** - Automated checks in CI/CD
- **Share knowledge** - Reusable reference data

## Similarity to AI-Allies Approach

This structure is inspired by how AI-Allies organizes BG3 knowledge:

| AI-Allies | This Reference Structure |
|-----------|-------------------------|
| `documents/knowledge_base/` | `reference/vanilla_data/` |
| Wiki text organized by topic | Game data organized by type |
| Semantic search for validation | Syntax validation for modding |
| LlamaIndex for queries | Python scripts for validation |
| Streamlit UI for access | Command-line tools for checking |

**Key Difference:** AI-Allies focuses on lore and gameplay knowledge for players, while this structure focuses on technical game data for modders.

## Extending the Reference

### Adding New Reference Data

1. **Extract vanilla examples** - Use BG3 tools to view game files
2. **Format properly** - Match existing reference file style
3. **Add comments** - Explain properties and valid values
4. **Include validation checklist** - Help others use the reference
5. **Test examples** - Verify they work in-game

### Adding New Validation Scripts

1. **Identify validation need** - What errors occur frequently?
2. **Write script** - Follow existing script patterns
3. **Add documentation** - Usage and output examples
4. **Test thoroughly** - Verify catches real errors
5. **Update guides** - Add to VALIDATION_GUIDE.md

### Updating for New Patches

When BG3 updates:

1. **Review patch notes** - Check for data structure changes
2. **Test existing references** - Verify still valid
3. **Add new examples** - Include new vanilla features
4. **Update scripts** - Handle new validation requirements
5. **Document changes** - Note what modders need to update

## Resources

### BG3 Modding Tools
- [LSLib Toolkit](https://github.com/Norbyte/lslib) - Extract and convert BG3 files
- [BG3 Script Extender](https://github.com/Norbyte/bg3se) - Advanced modding capabilities
- [BG3 Mod Manager](https://github.com/LaughingLeader/BG3ModManager) - Manage mods

### Documentation
- [BG3 Wiki - Modding](https://bg3.wiki/wiki/Modding:Modding_resources)
- [Larian Docs](https://docs.larian.game) - Official modding documentation
- [VALIDATION_GUIDE.md](../VALIDATION_GUIDE.md) - Comprehensive validation guide

### Community
- [BG3 Modding Discord](https://discord.gg/bg3mods)
- [Nexus Mods Forums](https://forums.nexusmods.com/index.php?/forum/5264-baldurs-gate-3/)

## Version Compatibility

- **Current Version:** 1.0
- **BG3 Patch:** Patch 8 (Build 6758295)
- **Last Updated:** 2025-12-27

When BG3 updates, this reference structure will be updated to reflect any changes in data format or valid values.

## Contributing

Contributions are welcome! If you:

- Find errors in reference data
- Have better examples to share
- Want to add new validation scripts
- Can improve documentation

Please see [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## License

This reference structure and validation tools are part of the Eldertide Armaments mod project. The reference data is derived from vanilla BG3 data and is provided for educational and modding purposes.

---

*For detailed validation instructions and error solutions, see [VALIDATION_GUIDE.md](../VALIDATION_GUIDE.md)*
