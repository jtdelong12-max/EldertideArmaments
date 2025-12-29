#!/usr/bin/env python3
"""
BG3 Spell Definition Validator

This script validates spell definitions in BG3 mod files against known valid values
and patterns from vanilla Baldur's Gate 3 data.

Usage:
    python3 validate_spells.py <path_to_spell_files_or_directory>

Example:
    python3 validate_spells.py Public/EldertideArmament/Stats/Generated/Data/
    python3 validate_spells.py Public/EldertideArmament/Stats/Generated/Data/Spells_Eldertide_Main.txt
"""

import sys
import os
import re
from pathlib import Path
from typing import List, Dict, Tuple

# Pre-compiled regex patterns for better performance
_ENTRY_PATTERN = re.compile(r'new entry "([^"]+)"')
_DATA_PATTERN = re.compile(r'data "([^"]+)" "([^"]*)"')
_USE_COSTS_COMMA_ERROR = re.compile(r'\w+:\d+,\s*\w+(?::|$)')

# Valid values from BG3 vanilla data
VALID_SPELL_TYPES = {
    "Projectile", "Target", "Zone", "Shout", "Rush", "Wall", 
    "Teleportation", "Throw", "MultiStrike"
}

VALID_SPELL_SCHOOLS = {
    "Abjuration", "Conjuration", "Divination", "Enchantment",
    "Evocation", "Illusion", "Necromancy", "Transmutation"
}

VALID_DAMAGE_TYPES = {
    "Acid", "Bludgeoning", "Cold", "Fire", "Force",
    "Lightning", "Necrotic", "Piercing", "Poison",
    "Psychic", "Radiant", "Slashing", "Thunder"
}

VALID_SPELL_FLAGS = {
    "HasVerbalComponent", "HasSomaticComponent", "IsSpell", "IsRitual",
    "HasHighGroundRangeExtension", "Concentration", "IsHarmful",
    "CombatLogSetSingleLineRoll", "IsMelee", "IsLinkedSpellContainer",
    "AddFallDamageOnLand", "IgnoreVisionBlock", "IgnoreSilence",
    "IsConcentration", "CanAreaDamageEvade", "RangeIgnoreVerticalThreshold",
    "CannotTargetItems", "CannotTargetCharacter", "Temporary", "DisableBlood",
    "IsEnemySpell", "CannotRotate", "IgnoreSurfaceCover", "TrajectoryRules",
    "UnavailableInDialogs", "Invisible", "NoSurprise",
    "IsAttack", "UNUSED_C", "CannotTargetTerrain", "Wildshape",
    "IgnorePreviouslyPickedEntities", "IsJump", "ImmediateCast",
    "SteeringSpeedOverride", "CallListeners", "DisablePortraitIndicator",
    "NoCooldownOnMiss"
}

class ValidationError:
    def __init__(self, file_path: str, line_num: int, entry_name: str, 
                 property_name: str, value: str, message: str):
        self.file_path = file_path
        self.line_num = line_num
        self.entry_name = entry_name
        self.property_name = property_name
        self.value = value
        self.message = message

    def __str__(self):
        return (f"❌ {self.file_path}:{self.line_num} - {self.entry_name}\n"
                f"   Property: {self.property_name}\n"
                f"   Value: {self.value}\n"
                f"   Error: {self.message}\n")

def parse_spell_entry(lines: List[str], start_idx: int) -> Tuple[Dict[str, str], int]:
    """Parse a single spell entry and return properties dict and end index."""
    entry = {}
    entry_name = ""
    i = start_idx
    
    # Get entry name - use pre-compiled pattern
    match = _ENTRY_PATTERN.match(lines[i])
    if match:
        entry_name = match.group(1)
        entry["_name"] = entry_name
        entry["_start_line"] = i + 1
    
    i += 1
    
    # Parse properties until next entry or end
    while i < len(lines):
        line = lines[i].strip()
        
        # Check for next entry
        if line.startswith("new entry"):
            break
            
        # Parse data line - use pre-compiled pattern
        match = _DATA_PATTERN.match(line)
        if match:
            key = match.group(1)
            value = match.group(2)
            entry[key] = value
        
        i += 1
    
    return entry, i

def validate_spell_type(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate SpellType property."""
    errors = []
    
    if "SpellType" in entry:
        spell_type = entry["SpellType"]
        if spell_type not in VALID_SPELL_TYPES:
            errors.append(ValidationError(
                file_path, entry["_start_line"], entry["_name"],
                "SpellType", spell_type,
                f"Invalid SpellType. Valid options: {', '.join(sorted(VALID_SPELL_TYPES))}"
            ))
    
    return errors

def validate_spell_level(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate Level property."""
    errors = []
    
    if "Level" in entry:
        try:
            level = int(entry["Level"])
            if level < 0 or level > 9:
                errors.append(ValidationError(
                    file_path, entry["_start_line"], entry["_name"],
                    "Level", str(level),
                    "Level must be between 0 (cantrip) and 9"
                ))
        except ValueError:
            errors.append(ValidationError(
                file_path, entry["_start_line"], entry["_name"],
                "Level", entry["Level"],
                "Level must be a number"
            ))
    
    return errors

def validate_spell_school(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate SpellSchool property."""
    errors = []
    
    if "SpellSchool" in entry:
        school = entry["SpellSchool"]
        if school not in VALID_SPELL_SCHOOLS:
            errors.append(ValidationError(
                file_path, entry["_start_line"], entry["_name"],
                "SpellSchool", school,
                f"Invalid SpellSchool. Valid options: {', '.join(sorted(VALID_SPELL_SCHOOLS))}"
            ))
    
    return errors

def validate_damage_type(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate DamageType property."""
    errors = []
    
    if "DamageType" in entry:
        damage_type = entry["DamageType"]
        if damage_type not in VALID_DAMAGE_TYPES:
            errors.append(ValidationError(
                file_path, entry["_start_line"], entry["_name"],
                "DamageType", damage_type,
                f"Invalid DamageType. Valid options: {', '.join(sorted(VALID_DAMAGE_TYPES))}"
            ))
    
    return errors

def validate_spell_flags(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate SpellFlags property."""
    errors = []
    
    if "SpellFlags" in entry:
        flags_str = entry["SpellFlags"]
        flags = [f.strip() for f in flags_str.split(";")]
        
        for flag in flags:
            if flag and flag not in VALID_SPELL_FLAGS:
                errors.append(ValidationError(
                    file_path, entry["_start_line"], entry["_name"],
                    "SpellFlags", flag,
                    f"Unknown SpellFlag. Common flags: {', '.join(sorted(VALID_SPELL_FLAGS)[:5])}"
                ))
    
    return errors

def validate_use_costs(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate UseCosts property format."""
    errors = []
    
    if "UseCosts" in entry:
        costs = entry["UseCosts"]
        
        # Check for malformed costs with commas in wrong places - use pre-compiled pattern
        if _USE_COSTS_COMMA_ERROR.search(costs):
            errors.append(ValidationError(
                file_path, entry["_start_line"], entry["_name"],
                "UseCosts", costs,
                "UseCosts should use semicolons (;) not commas (,) to separate multiple costs"
            ))
        
        # Validate cost format
        cost_parts = [c.strip() for c in costs.split(";")]
        for cost in cost_parts:
            if cost and ":" not in cost:
                errors.append(ValidationError(
                    file_path, entry["_start_line"], entry["_name"],
                    "UseCosts", cost,
                    "Each cost should be in format 'ResourceType:Amount' or 'ResourceType:Amount:Level'"
                ))
    
    return errors

def validate_spell_file(file_path: str) -> Tuple[int, List[ValidationError]]:
    """Validate a single spell file."""
    errors = []
    valid_count = 0
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        errors.append(ValidationError(
            file_path, 0, "", "", "", f"Failed to read file: {e}"
        ))
        return 0, errors
    
    # Track entries with errors using a set for O(1) lookups
    entries_with_errors = set()
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Find spell entry - optimized to avoid unnecessary string joining
        if line.startswith('new entry'):
            # Check next few lines for type without joining (more efficient)
            is_spell_data = any('type "SpellData"' in lines[i+j] for j in range(min(5, len(lines)-i)))
            
            if is_spell_data:
                entry, next_i = parse_spell_entry(lines, i)
                entry_name = entry["_name"]
                
                # Run all validations and track if any errors occur
                entry_errors_before = len(errors)
                errors.extend(validate_spell_type(entry, file_path))
                errors.extend(validate_spell_level(entry, file_path))
                errors.extend(validate_spell_school(entry, file_path))
                errors.extend(validate_damage_type(entry, file_path))
                errors.extend(validate_spell_flags(entry, file_path))
                errors.extend(validate_use_costs(entry, file_path))
                
                # Check if new errors were added (O(1) instead of O(n))
                if len(errors) == entry_errors_before:
                    valid_count += 1
                else:
                    entries_with_errors.add(entry_name)
                
                i = next_i
            else:
                i += 1
        else:
            i += 1
    
    return valid_count, errors

def validate_directory(directory: str) -> Tuple[int, List[ValidationError]]:
    """Validate all spell files in a directory."""
    all_errors = []
    total_valid = 0
    
    path = Path(directory)
    
    # Find all spell files
    spell_files = []
    if path.is_file():
        if "Spell" in path.name and path.suffix == ".txt":
            spell_files = [path]
    else:
        spell_files = list(path.glob("**/Spell*.txt"))
    
    if not spell_files:
        print(f"❌ No spell files found in {directory}")
        return 0, []
    
    print(f"📁 Found {len(spell_files)} spell file(s) to validate\n")
    
    # Process files with progress indication
    for idx, spell_file in enumerate(spell_files, 1):
        file_size = spell_file.stat().st_size / 1024  # Size in KB
        print(f"🔍 [{idx}/{len(spell_files)}] Validating: {spell_file.name} ({file_size:.1f} KB)")
        valid, errors = validate_spell_file(str(spell_file))
        total_valid += valid
        all_errors.extend(errors)
        
        if errors:
            print(f"   ⚠️  Found {len(errors)} error(s)")
        else:
            print(f"   ✅ All {valid} spell(s) valid")
        print()
    
    return total_valid, all_errors

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    target = sys.argv[1]
    
    if not os.path.exists(target):
        print(f"❌ Error: Path does not exist: {target}")
        sys.exit(1)
    
    print("=" * 70)
    print("BG3 Spell Definition Validator")
    print("=" * 70)
    print()
    
    valid_count, errors = validate_directory(target)
    
    # Collect unique entry names in a single pass
    error_entry_names = set(e.entry_name for e in errors)
    
    # Print detailed errors
    if errors:
        print("=" * 70)
        print("VALIDATION ERRORS")
        print("=" * 70)
        print()
        for error in errors:
            print(error)
    
    # Print summary
    print("=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)
    print(f"✅ Valid spells: {valid_count}")
    print(f"❌ Spells with errors: {len(error_entry_names)}")
    print(f"⚠️  Total errors: {len(errors)}")
    print()
    
    if errors:
        print("❌ Validation FAILED")
        sys.exit(1)
    else:
        print("✅ Validation PASSED")
        sys.exit(0)

if __name__ == "__main__":
    main()
