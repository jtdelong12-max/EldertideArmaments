#!/usr/bin/env python3
"""
BG3 Item/Armor Definition Validator

This script validates item and armor definitions in BG3 mod files against known 
valid values and patterns from vanilla Baldur's Gate 3 data.

Usage:
    python3 validate_items.py <path_to_item_files_or_directory>

Example:
    python3 validate_items.py Public/EldertideArmament/Stats/Generated/Data/
    python3 validate_items.py Public/EldertideArmament/Stats/Generated/Data/Armor.txt
"""

import sys
import os
import re
from pathlib import Path
from typing import List, Dict, Tuple

# Try to import caching module (optional dependency)
try:
    from validation_cache import ValidationCache
    CACHING_AVAILABLE = True
except ImportError:
    CACHING_AVAILABLE = False

# Pre-compiled regex patterns for better performance
_ENTRY_PATTERN = re.compile(r'new entry "([^"]+)"')
_USING_PATTERN = re.compile(r'using "([^"]+)"')
_DATA_PATTERN = re.compile(r'data "([^"]+)" "([^"]*)"')
_UUID_FORMAT = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.IGNORECASE)
_ABILITY_BOOST_PATTERN = re.compile(r'Ability\((\w+),\s*(\d+),\s*(\d+)\)')
_COMMA_SEPARATOR_ERROR = re.compile(r'\),\s*\w+\(')

# Configuration constants
MAX_ABILITY_CAP = 30  # Maximum reasonable ability score cap
MAX_ABILITY_BONUS = 10  # Maximum reasonable ability bonus

# Valid values from BG3 vanilla data
VALID_USING_TYPES = {
    "_Ring", "_Amulet", "_Helmet", "_Boots", "_Gloves", "_Armor", 
    "_Cloak", "_Clothes", "_Shield", "_Weapon"
}

VALID_OBJECT_CATEGORIES = {
    "Jewelry", "Armor", "Weapon", "Consumable", "Miscellaneous"
}

VALID_RARITIES = {
    "Common", "Uncommon", "Rare", "VeryRare", "Legendary", 
    "Divine", "Unique", "Sentient"
}

VALID_ABILITIES = {
    "Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"
}

# Pre-compute sorted strings for error messages (performance optimization)
_VALID_USING_TYPES_STR = ', '.join(sorted(VALID_USING_TYPES))
_VALID_OBJECT_CATEGORIES_STR = ', '.join(sorted(VALID_OBJECT_CATEGORIES))
_VALID_RARITIES_STR = ', '.join(sorted(VALID_RARITIES))
_VALID_ABILITIES_STR = ', '.join(sorted(VALID_ABILITIES))

class ValidationError:
    def __init__(self, file_path: str, line_num: int, entry_name: str, 
                 property_name: str, value: str, message: str, severity: str = "error"):
        self.file_path = file_path
        self.line_num = line_num
        self.entry_name = entry_name
        self.property_name = property_name
        self.value = value
        self.message = message
        self.severity = severity  # "error" or "warning"

    def __str__(self):
        icon = "❌" if self.severity == "error" else "⚠️"
        return (f"{icon} {self.file_path}:{self.line_num} - {self.entry_name}\n"
                f"   Property: {self.property_name}\n"
                f"   Value: {self.value}\n"
                f"   {self.severity.title()}: {self.message}\n")

def parse_item_entry(lines: List[str], start_idx: int) -> Tuple[Dict[str, str], int]:
    """Parse a single item entry and return properties dict and end index."""
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
            
        # Parse using line - use pre-compiled pattern
        match = _USING_PATTERN.match(line)
        if match:
            entry["using"] = match.group(1)
        
        # Parse data line - use pre-compiled pattern
        match = _DATA_PATTERN.match(line)
        if match:
            key = match.group(1)
            value = match.group(2)
            entry[key] = value
        
        i += 1
    
    return entry, i

def validate_using_clause(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate using clause."""
    errors = []
    
    if "using" in entry:
        using = entry["using"]
        if using not in VALID_USING_TYPES:
            # Cache dict lookups for performance
            entry_name = entry["_name"]
            entry_line = entry["_start_line"]
            errors.append(ValidationError(
                file_path, entry_line, entry_name,
                "using", using,
                f"Invalid base type. Valid options: {_VALID_USING_TYPES_STR}",
                "error"
            ))
    
    return errors

def validate_uuid(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate RootTemplate UUID format."""
    errors = []
    
    if "RootTemplate" in entry:
        uuid = entry["RootTemplate"]
        # Use pre-compiled UUID pattern
        if not _UUID_FORMAT.match(uuid):
            # Cache dict lookups for performance
            entry_name = entry["_name"]
            entry_line = entry["_start_line"]
            errors.append(ValidationError(
                file_path, entry_line, entry_name,
                "RootTemplate", uuid,
                "Invalid UUID format. Should be: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                "error"
            ))
    
    return errors

def validate_object_category(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate ObjectCategory."""
    errors = []
    
    if "ObjectCategory" in entry:
        category = entry["ObjectCategory"]
        if category not in VALID_OBJECT_CATEGORIES:
            # Cache dict lookups for performance
            entry_name = entry["_name"]
            entry_line = entry["_start_line"]
            errors.append(ValidationError(
                file_path, entry_line, entry_name,
                "ObjectCategory", category,
                f"Invalid ObjectCategory. Valid options: {_VALID_OBJECT_CATEGORIES_STR}",
                "error"
            ))
    
    return errors

def validate_rarity(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate Rarity."""
    errors = []
    
    if "Rarity" in entry:
        rarity = entry["Rarity"]
        if rarity not in VALID_RARITIES:
            # Cache dict lookups for performance
            entry_name = entry["_name"]
            entry_line = entry["_start_line"]
            errors.append(ValidationError(
                file_path, entry_line, entry_name,
                "Rarity", rarity,
                f"Invalid Rarity. Valid options: {_VALID_RARITIES_STR}",
                "error"
            ))
    
    return errors

def validate_boosts(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate Boosts property format and values."""
    errors = []
    
    if "Boosts" in entry:
        boosts = entry["Boosts"]
        
        # Cache dict lookups for performance
        entry_name = entry["_name"]
        entry_line = entry["_start_line"]
        
        # Check for comma instead of semicolon (common mistake) - use pre-compiled pattern
        if _COMMA_SEPARATOR_ERROR.search(boosts):
            errors.append(ValidationError(
                file_path, entry_line, entry_name,
                "Boosts", boosts[:50] + "...",
                "Boosts should use semicolons (;) not commas (,) to separate multiple boosts",
                "error"
            ))
        
        # Validate ability boosts - use pre-compiled pattern
        for match in _ABILITY_BOOST_PATTERN.finditer(boosts):
            ability = match.group(1)
            bonus = int(match.group(2))
            cap = int(match.group(3))
            
            if ability not in VALID_ABILITIES:
                errors.append(ValidationError(
                    file_path, entry_line, entry_name,
                    "Boosts", match.group(0),
                    f"Invalid ability '{ability}'. Valid: {_VALID_ABILITIES_STR}",
                    "error"
                ))
            
            if cap > MAX_ABILITY_CAP:
                errors.append(ValidationError(
                    file_path, entry_line, entry_name,
                    "Boosts", match.group(0),
                    f"Ability cap {cap} exceeds reasonable maximum ({MAX_ABILITY_CAP}). Consider balance.",
                    "warning"
                ))
            
            if bonus > MAX_ABILITY_BONUS:
                errors.append(ValidationError(
                    file_path, entry_line, entry_name,
                    "Boosts", match.group(0),
                    f"Ability bonus +{bonus} is very high. Consider balance.",
                    "warning"
                ))
    
    return errors

def validate_value(entry: Dict[str, str], file_path: str) -> List[ValidationError]:
    """Validate ValueOverride is reasonable for rarity."""
    errors = []
    
    if "ValueOverride" in entry and "Rarity" in entry:
        value_str = entry["ValueOverride"]
        rarity = entry["Rarity"]
        
        # Cache dict lookups for performance
        entry_name = entry["_name"]
        entry_line = entry["_start_line"]
        
        try:
            value = int(value_str)
            
            # Suggested value ranges by rarity (these are guidelines)
            rarity_ranges = {
                "Common": (1, 50),
                "Uncommon": (40, 200),
                "Rare": (150, 600),
                "VeryRare": (500, 2000),
                "Legendary": (1000, 5000),
            }
            
            if rarity in rarity_ranges:
                min_val, max_val = rarity_ranges[rarity]
                if value < min_val or value > max_val:
                    errors.append(ValidationError(
                        file_path, entry_line, entry_name,
                        "ValueOverride", str(value),
                        f"{rarity} items typically valued {min_val}-{max_val}. Current: {value}",
                        "warning"
                    ))
        except ValueError:
            errors.append(ValidationError(
                file_path, entry_line, entry_name,
                "ValueOverride", value_str,
                "ValueOverride should be a number",
                "error"
            ))
    
    return errors

def validate_item_file(file_path: str, cache: 'ValidationCache' = None) -> Tuple[int, List[ValidationError]]:
    """Validate a single item file."""
    
    # Try to load from cache if available
    if cache and CACHING_AVAILABLE:
        cached = cache.load_cached_results(file_path)
        if cached is not None:
            return cached
    
    errors = []
    valid_count = 0
    entry_errors = {}  # Track errors per entry name
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        errors.append(ValidationError(
            file_path, 0, "", "", "", f"Failed to read file: {e}", "error"
        ))
        return 0, errors
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Find item entry (Armor type) - optimized to avoid unnecessary string joining
        if line.startswith('new entry'):
            # Check next few lines for type without joining (more efficient)
            # Ensure we don't go beyond array bounds
            max_lookahead = min(5, len(lines) - i)
            is_armor_type = any('type "Armor"' in lines[i+j] for j in range(max_lookahead))
            
            if is_armor_type:
                entry, next_i = parse_item_entry(lines, i)
                entry_name = entry.get("_name", "")
                
                # Run all validations and collect errors for this entry
                entry_errors[entry_name] = []
                entry_errors[entry_name].extend(validate_using_clause(entry, file_path))
                entry_errors[entry_name].extend(validate_uuid(entry, file_path))
                entry_errors[entry_name].extend(validate_object_category(entry, file_path))
                entry_errors[entry_name].extend(validate_rarity(entry, file_path))
                entry_errors[entry_name].extend(validate_boosts(entry, file_path))
                entry_errors[entry_name].extend(validate_value(entry, file_path))
                
                # Add entry errors to global list
                errors.extend(entry_errors[entry_name])
                
                # Count as valid if no errors (warnings OK)
                has_errors = any(e.severity == "error" for e in entry_errors[entry_name])
                if not has_errors:
                    valid_count += 1
                
                i = next_i
            else:
                i += 1
        else:
            i += 1
    
    results = (valid_count, errors)
    
    # Save to cache if available
    if cache and CACHING_AVAILABLE:
        cache.save_cached_results(file_path, results)
    
    return results

def validate_directory(directory: str) -> Tuple[int, List[ValidationError]]:
    """Validate all item files in a directory."""
    all_errors = []
    total_valid = 0
    
    # Initialize cache if available
    cache = ValidationCache() if CACHING_AVAILABLE else None
    
    path = Path(directory)
    
    # Find all item files
    item_files = []
    if path.is_file():
        if path.suffix == ".txt":
            item_files = [path]
    else:
        # Look for Armor.txt, Object.txt, etc.
        item_files = list(path.glob("**/Armor.txt"))
        item_files.extend(path.glob("**/Object.txt"))
    
    if not item_files:
        print(f"❌ No item files found in {directory}")
        return 0, []
    
    print(f"📁 Found {len(item_files)} item file(s) to validate")
    if cache and CACHING_AVAILABLE:
        print(f"💾 Caching enabled\n")
    else:
        print()
    
    # Process files with progress indication
    for idx, item_file in enumerate(item_files, 1):
        file_size = item_file.stat().st_size / 1024  # Size in KB
        print(f"🔍 [{idx}/{len(item_files)}] Validating: {item_file.name} ({file_size:.1f} KB)")
        valid, errors = validate_item_file(str(item_file), cache)
        total_valid += valid
        all_errors.extend(errors)
        
        # Count errors and warnings in a single pass with early exit optimization
        error_count = sum(1 for e in errors if e.severity == "error")
        warning_count = len(errors) - error_count  # More efficient than second iteration
        
        if error_count > 0:
            print(f"   ❌ Found {error_count} error(s)")
        if warning_count > 0:
            print(f"   ⚠️  Found {warning_count} warning(s)")
        if error_count == 0 and warning_count == 0:
            print(f"   ✅ All {valid} item(s) valid")
        print()
    
    # Print cache stats if available
    if cache and CACHING_AVAILABLE:
        cache.print_stats()
    
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
    print("BG3 Item/Armor Definition Validator")
    print("=" * 70)
    print()
    
    valid_count, all_errors = validate_directory(target)
    
    # Separate errors and warnings in a single pass
    errors = []
    warnings = []
    error_entry_names = set()
    warning_entry_names = set()
    
    for e in all_errors:
        if e.severity == "error":
            errors.append(e)
            error_entry_names.add(e.entry_name)
        else:
            warnings.append(e)
            warning_entry_names.add(e.entry_name)
    
    # Print detailed errors
    if errors:
        print("=" * 70)
        print("VALIDATION ERRORS")
        print("=" * 70)
        print()
        for error in errors:
            print(error)
    
    # Print warnings
    if warnings:
        print("=" * 70)
        print("VALIDATION WARNINGS")
        print("=" * 70)
        print()
        for warning in warnings:
            print(warning)
    
    # Print summary
    print("=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)
    print(f"✅ Valid items: {valid_count}")
    print(f"❌ Items with errors: {len(error_entry_names)}")
    print(f"⚠️  Items with warnings: {len(warning_entry_names)}")
    print(f"   Total errors: {len(errors)}")
    print(f"   Total warnings: {len(warnings)}")
    print()
    
    if errors:
        print("❌ Validation FAILED (errors found)")
        sys.exit(1)
    elif warnings:
        print("⚠️  Validation PASSED with warnings")
        sys.exit(0)
    else:
        print("✅ Validation PASSED")
        sys.exit(0)

if __name__ == "__main__":
    main()
