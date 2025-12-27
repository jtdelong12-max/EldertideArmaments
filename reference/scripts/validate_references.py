#!/usr/bin/env python3
"""
BG3 Cross-Reference Validator

This script validates cross-references between different BG3 mod files to ensure
all spell unlocks, passive references, and status applications point to existing entries.

Usage:
    python3 validate_references.py <path_to_mod_directory>

Example:
    python3 validate_references.py Public/EldertideArmament/
"""

import sys
import os
import re
from pathlib import Path
from typing import List, Dict, Set, Tuple
from collections import defaultdict

class ReferenceError:
    def __init__(self, file_path: str, line_num: int, entry_name: str, 
                 ref_type: str, ref_name: str, message: str):
        self.file_path = file_path
        self.line_num = line_num
        self.entry_name = entry_name
        self.ref_type = ref_type
        self.ref_name = ref_name
        self.message = message

    def __str__(self):
        return (f"❌ {self.file_path}:{self.line_num} - {self.entry_name}\n"
                f"   Reference Type: {self.ref_type}\n"
                f"   Missing: {self.ref_name}\n"
                f"   Error: {self.message}\n")

def find_all_entries(directory: str, entry_type: str) -> Dict[str, Tuple[str, int]]:
    """Find all entries of a specific type in directory."""
    entries = {}
    
    path = Path(directory)
    for file_path in path.rglob("*.txt"):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            for i, line in enumerate(lines):
                # Match: new entry "EntryName"
                match = re.match(r'new entry "([^"]+)"', line.strip())
                if match:
                    entry_name = match.group(1)
                    
                    # Check if it's the right type (in next few lines)
                    type_check = ''.join(lines[i:min(i+5, len(lines))])
                    if f'type "{entry_type}"' in type_check:
                        if entry_name in entries:
                            # Duplicate entry (report separately)
                            pass
                        else:
                            entries[entry_name] = (str(file_path), i + 1)
        except Exception:
            continue
    
    return entries

def find_all_uuids(directory: str) -> Dict[str, List[Tuple[str, int, str]]]:
    """Find all RootTemplate UUIDs and their locations."""
    uuid_locations = defaultdict(list)
    
    path = Path(directory)
    for file_path in path.rglob("*.txt"):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            current_entry = ""
            for i, line in enumerate(lines):
                # Track current entry name
                match = re.match(r'new entry "([^"]+)"', line.strip())
                if match:
                    current_entry = match.group(1)
                
                # Find UUID
                match = re.match(r'data "RootTemplate" "([^"]+)"', line.strip())
                if match:
                    uuid = match.group(1)
                    uuid_locations[uuid].append((str(file_path), i + 1, current_entry))
        except Exception:
            continue
    
    return uuid_locations

def find_references(directory: str, ref_pattern: str, ref_type: str) -> List[Tuple[str, int, str, str]]:
    """Find all references matching a pattern."""
    references = []
    
    path = Path(directory)
    for file_path in path.rglob("*.txt"):
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            current_entry = ""
            for i, line in enumerate(lines):
                # Track current entry name
                match = re.match(r'new entry "([^"]+)"', line.strip())
                if match:
                    current_entry = match.group(1)
                
                # Find references
                for match in re.finditer(ref_pattern, line):
                    ref_name = match.group(1)
                    references.append((str(file_path), i + 1, current_entry, ref_name))
        except Exception:
            continue
    
    return references

def validate_spell_references(directory: str) -> List[ReferenceError]:
    """Validate UnlockSpell() references."""
    errors = []
    
    print("🔍 Finding all spell definitions...")
    spells = find_all_entries(directory, "SpellData")
    print(f"   Found {len(spells)} spell definitions")
    
    print("🔍 Finding all spell references...")
    spell_refs = find_references(directory, r'UnlockSpell\(([^)]+)\)', "UnlockSpell")
    print(f"   Found {len(spell_refs)} spell references")
    print()
    
    for file_path, line_num, entry_name, spell_name in spell_refs:
        if spell_name not in spells:
            errors.append(ReferenceError(
                file_path, line_num, entry_name,
                "UnlockSpell", spell_name,
                f"Spell '{spell_name}' is referenced but not defined"
            ))
    
    return errors

def validate_passive_references(directory: str) -> List[ReferenceError]:
    """Validate PassivesOnEquip references."""
    errors = []
    
    print("🔍 Finding all passive definitions...")
    passives = find_all_entries(directory, "PassiveData")
    print(f"   Found {len(passives)} passive definitions")
    
    print("🔍 Finding all passive references...")
    passive_refs = find_references(directory, r'data "PassivesOnEquip" "([^"]+)"', "PassivesOnEquip")
    print(f"   Found {len(passive_refs)} passive references")
    print()
    
    for file_path, line_num, entry_name, passives_str in passive_refs:
        if not passives_str:
            continue
            
        # Multiple passives can be separated by semicolons
        passive_list = [p.strip() for p in passives_str.split(";")]
        
        for passive_name in passive_list:
            if passive_name and passive_name not in passives:
                errors.append(ReferenceError(
                    file_path, line_num, entry_name,
                    "PassivesOnEquip", passive_name,
                    f"Passive '{passive_name}' is referenced but not defined"
                ))
    
    return errors

def validate_status_references(directory: str) -> List[ReferenceError]:
    """Validate status effect references."""
    errors = []
    
    print("🔍 Finding all status definitions...")
    statuses = find_all_entries(directory, "StatusData")
    print(f"   Found {len(statuses)} status definitions")
    
    print("🔍 Finding all status references...")
    # StatusOnEquip
    status_refs = find_references(directory, r'data "StatusOnEquip" "([^"]+)"', "StatusOnEquip")
    # ApplyStatus calls
    status_refs.extend(find_references(directory, r'ApplyStatus\([^,]+,([^,)]+)', "ApplyStatus"))
    print(f"   Found {len(status_refs)} status references")
    print()
    
    for file_path, line_num, entry_name, status_name in status_refs:
        if not status_name or status_name in ["SELF", "TARGET", "SOURCE"]:
            continue
            
        # Clean up the status name (remove quotes, whitespace)
        status_name = status_name.strip().strip('"\'')
        
        if status_name and status_name not in statuses:
            errors.append(ReferenceError(
                file_path, line_num, entry_name,
                "Status", status_name,
                f"Status '{status_name}' is referenced but not defined"
            ))
    
    return errors

def validate_uuid_uniqueness(directory: str) -> List[ReferenceError]:
    """Check for duplicate UUIDs."""
    errors = []
    
    print("🔍 Finding all RootTemplate UUIDs...")
    uuid_locations = find_all_uuids(directory)
    print(f"   Found {len(uuid_locations)} unique UUIDs")
    print()
    
    for uuid, locations in uuid_locations.items():
        if len(locations) > 1:
            # Duplicate UUID found
            for file_path, line_num, entry_name in locations:
                errors.append(ReferenceError(
                    file_path, line_num, entry_name,
                    "UUID", uuid,
                    f"UUID '{uuid}' is used {len(locations)} times (must be unique)"
                ))
    
    return errors

def validate_directory(directory: str) -> List[ReferenceError]:
    """Validate all cross-references in directory."""
    all_errors = []
    
    print("=" * 70)
    print("Validating Spell References")
    print("=" * 70)
    spell_errors = validate_spell_references(directory)
    all_errors.extend(spell_errors)
    
    if spell_errors:
        print(f"❌ Found {len(spell_errors)} broken spell reference(s)\n")
    else:
        print("✅ All spell references valid\n")
    
    print("=" * 70)
    print("Validating Passive References")
    print("=" * 70)
    passive_errors = validate_passive_references(directory)
    all_errors.extend(passive_errors)
    
    if passive_errors:
        print(f"❌ Found {len(passive_errors)} broken passive reference(s)\n")
    else:
        print("✅ All passive references valid\n")
    
    print("=" * 70)
    print("Validating Status References")
    print("=" * 70)
    status_errors = validate_status_references(directory)
    all_errors.extend(status_errors)
    
    if status_errors:
        print(f"❌ Found {len(status_errors)} broken status reference(s)\n")
    else:
        print("✅ All status references valid\n")
    
    print("=" * 70)
    print("Validating UUID Uniqueness")
    print("=" * 70)
    uuid_errors = validate_uuid_uniqueness(directory)
    all_errors.extend(uuid_errors)
    
    if uuid_errors:
        print(f"❌ Found {len(uuid_errors)} duplicate UUID(s)\n")
    else:
        print("✅ All UUIDs are unique\n")
    
    return all_errors

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    target = sys.argv[1]
    
    if not os.path.exists(target):
        print(f"❌ Error: Path does not exist: {target}")
        sys.exit(1)
    
    if not os.path.isdir(target):
        print(f"❌ Error: Path must be a directory: {target}")
        sys.exit(1)
    
    print("=" * 70)
    print("BG3 Cross-Reference Validator")
    print("=" * 70)
    print()
    
    errors = validate_directory(target)
    
    # Print detailed errors
    if errors:
        print("=" * 70)
        print("REFERENCE ERRORS")
        print("=" * 70)
        print()
        for error in errors:
            print(error)
    
    # Print summary
    print("=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)
    
    error_by_type = defaultdict(int)
    for error in errors:
        error_by_type[error.ref_type] += 1
    
    for ref_type, count in error_by_type.items():
        print(f"❌ {ref_type}: {count} broken reference(s)")
    
    print(f"\n⚠️  Total errors: {len(errors)}")
    print()
    
    if errors:
        print("❌ Validation FAILED")
        sys.exit(1)
    else:
        print("✅ Validation PASSED - All references valid!")
        sys.exit(0)

if __name__ == "__main__":
    main()
