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

# Pre-compiled regex patterns for better performance
_ENTRY_PATTERN = re.compile(r'new entry "([^"]+)"')
_UUID_PATTERN = re.compile(r'data "RootTemplate" "([^"]+)"')
_UNLOCK_SPELL_PATTERN = re.compile(r'UnlockSpell\(([^)]+)\)')
_PASSIVES_ON_EQUIP_PATTERN = re.compile(r'data "PassivesOnEquip" "([^"]+)"')
_STATUS_ON_EQUIP_PATTERN = re.compile(r'data "StatusOnEquip" "([^"]+)"')
_APPLY_STATUS_PATTERN = re.compile(r'ApplyStatus\(([^,)]+)(?:,([^,)]+))?')

# Constant set for ignored status target keywords (module level for performance)
_IGNORE_TARGETS = frozenset({"SELF", "TARGET", "SOURCE", "SWAP", ""})

class ParsedData:
    """Container for all parsed data from directory."""
    def __init__(self):
        self.spells = {}  # spell_name -> (file_path, line_num)
        self.passives = {}  # passive_name -> (file_path, line_num)
        self.statuses = {}  # status_name -> (file_path, line_num)
        self.uuids = defaultdict(list)  # uuid -> [(file_path, line_num, entry_name)]
        self.spell_refs = []  # [(file_path, line_num, entry_name, spell_name)]
        self.passive_refs = []  # [(file_path, line_num, entry_name, passive_str)]
        self.status_refs = []  # [(file_path, line_num, entry_name, status_name)]

def parse_directory_single_pass(directory: str) -> ParsedData:
    """Parse all files once and extract all needed information.
    
    This is much more efficient than the original approach which read
    files multiple times for different purposes.
    """
    data = ParsedData()
    path = Path(directory)
    
    # Collect all files first for progress tracking
    txt_files = list(path.rglob("*.txt"))
    total_files = len(txt_files)
    
    if total_files == 0:
        return data
    
    print(f"📂 Parsing {total_files} file(s)...")
    
    for idx, file_path in enumerate(txt_files, 1):
        # Show progress every 5 files or for the last file
        if idx % 5 == 0 or idx == total_files:
            print(f"   Progress: {idx}/{total_files} files processed...")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            current_entry = ""
            current_entry_line = 0
            
            for i, line in enumerate(lines):
                stripped = line.strip()
                
                # Track current entry name
                match = _ENTRY_PATTERN.match(stripped)
                if match:
                    current_entry = match.group(1)
                    current_entry_line = i + 1
                    
                    # Check entry type in next few lines - optimized to check directly without joining
                    end_idx = min(i+5, len(lines))
                    for j in range(i, end_idx):
                        line_content = lines[j]
                        if 'type "SpellData"' in line_content:
                            data.spells[current_entry] = (str(file_path), current_entry_line)
                            break
                        elif 'type "PassiveData"' in line_content:
                            data.passives[current_entry] = (str(file_path), current_entry_line)
                            break
                        elif 'type "StatusData"' in line_content:
                            data.statuses[current_entry] = (str(file_path), current_entry_line)
                            break
                
                # Find UUID references
                match = _UUID_PATTERN.match(stripped)
                if match:
                    uuid = match.group(1)
                    data.uuids[uuid].append((str(file_path), i + 1, current_entry))
                
                # Find spell references
                for match in _UNLOCK_SPELL_PATTERN.finditer(line):
                    spell_name = match.group(1)
                    data.spell_refs.append((str(file_path), i + 1, current_entry, spell_name))
                
                # Find passive references
                match = _PASSIVES_ON_EQUIP_PATTERN.match(stripped)
                if match:
                    passives_str = match.group(1)
                    data.passive_refs.append((str(file_path), i + 1, current_entry, passives_str))
                
                # Find status references
                match = _STATUS_ON_EQUIP_PATTERN.match(stripped)
                if match:
                    status_name = match.group(1)
                    data.status_refs.append((str(file_path), i + 1, current_entry, status_name))
                
                # Find ApplyStatus references
                # ApplyStatus can have format: ApplyStatus(STATUS,...) or ApplyStatus(TARGET,STATUS,...)
                # We check both first and second parameters as potential status names
                # The validation phase will filter out targets (SELF, TARGET, SOURCE, SWAP) and numbers
                for match in _APPLY_STATUS_PATTERN.finditer(line):
                    param1 = match.group(1)
                    param2 = match.group(2) if match.lastindex >= 2 else None
                    
                    # Add first parameter (could be status or target)
                    data.status_refs.append((str(file_path), i + 1, current_entry, param1))
                    
                    # Add second parameter if it exists (could be status or duration)
                    if param2:
                        data.status_refs.append((str(file_path), i + 1, current_entry, param2))
            
        except Exception:
            continue
    
    return data

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

def validate_spell_references(parsed_data: ParsedData) -> List[ReferenceError]:
    """Validate UnlockSpell() references using pre-parsed data."""
    errors = []
    
    for file_path, line_num, entry_name, spell_name in parsed_data.spell_refs:
        if spell_name not in parsed_data.spells:
            errors.append(ReferenceError(
                file_path, line_num, entry_name,
                "UnlockSpell", spell_name,
                f"Spell '{spell_name}' is referenced but not defined"
            ))
    
    return errors

def validate_passive_references(parsed_data: ParsedData) -> List[ReferenceError]:
    """Validate PassivesOnEquip references using pre-parsed data."""
    errors = []
    
    for file_path, line_num, entry_name, passives_str in parsed_data.passive_refs:
        if not passives_str:
            continue
            
        # Multiple passives can be separated by semicolons
        passive_list = [p.strip() for p in passives_str.split(";")]
        
        for passive_name in passive_list:
            if passive_name and passive_name not in parsed_data.passives:
                errors.append(ReferenceError(
                    file_path, line_num, entry_name,
                    "PassivesOnEquip", passive_name,
                    f"Passive '{passive_name}' is referenced but not defined"
                ))
    
    return errors

def validate_status_references(parsed_data: ParsedData) -> List[ReferenceError]:
    """Validate status effect references using pre-parsed data."""
    errors = []
    
    for file_path, line_num, entry_name, status_name in parsed_data.status_refs:
        # Clean up the status name once (remove quotes, whitespace)
        status_name = status_name.strip().strip('"\'')
        
        # Combined check for empty, targets, or numeric values using module-level constant
        if not status_name or status_name in _IGNORE_TARGETS or status_name.isdigit():
            continue
        
        if status_name not in parsed_data.statuses:
            errors.append(ReferenceError(
                file_path, line_num, entry_name,
                "Status", status_name,
                f"Status '{status_name}' is referenced but not defined"
            ))
    
    return errors

def validate_uuid_uniqueness(parsed_data: ParsedData) -> List[ReferenceError]:
    """Check for duplicate UUIDs using pre-parsed data."""
    errors = []
    
    for uuid, locations in parsed_data.uuids.items():
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
    """Validate all cross-references in directory using single-pass parsing."""
    all_errors = []
    
    # Parse all files once - significant performance improvement
    print("🔍 Parsing all files (single pass)...")
    parsed_data = parse_directory_single_pass(directory)
    print(f"   Found {len(parsed_data.spells)} spell definitions")
    print(f"   Found {len(parsed_data.passives)} passive definitions")
    print(f"   Found {len(parsed_data.statuses)} status definitions")
    print(f"   Found {len(parsed_data.uuids)} unique UUIDs")
    print(f"   Found {len(parsed_data.spell_refs)} spell references")
    print(f"   Found {len(parsed_data.passive_refs)} passive references")
    print(f"   Found {len(parsed_data.status_refs)} status references")
    print()
    
    print("=" * 70)
    print("Validating Spell References")
    print("=" * 70)
    spell_errors = validate_spell_references(parsed_data)
    all_errors.extend(spell_errors)
    
    if spell_errors:
        print(f"❌ Found {len(spell_errors)} broken spell reference(s)\n")
    else:
        print("✅ All spell references valid\n")
    
    print("=" * 70)
    print("Validating Passive References")
    print("=" * 70)
    passive_errors = validate_passive_references(parsed_data)
    all_errors.extend(passive_errors)
    
    if passive_errors:
        print(f"❌ Found {len(passive_errors)} broken passive reference(s)\n")
    else:
        print("✅ All passive references valid\n")
    
    print("=" * 70)
    print("Validating Status References")
    print("=" * 70)
    status_errors = validate_status_references(parsed_data)
    all_errors.extend(status_errors)
    
    if status_errors:
        print(f"❌ Found {len(status_errors)} broken status reference(s)\n")
    else:
        print("✅ All status references valid\n")
    
    print("=" * 70)
    print("Validating UUID Uniqueness")
    print("=" * 70)
    uuid_errors = validate_uuid_uniqueness(parsed_data)
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
