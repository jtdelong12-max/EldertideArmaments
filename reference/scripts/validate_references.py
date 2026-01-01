#!/usr/bin/env python3
"""
BG3 Cross-Reference Validator

Validates cross-references between BG3 mod files to ensure spell unlocks,
passive references, and status applications point to existing entries.
"""

import argparse
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import List

# Pre-compiled regex patterns for better performance
_ENTRY_PATTERN = re.compile(r'new entry "([^"]+)"')
_UUID_PATTERN = re.compile(r'data "RootTemplate" "([^"]+)"')
_UNLOCK_SPELL_PATTERN = re.compile(r'UnlockSpell\(([^)]+)\)')
_PASSIVES_ON_EQUIP_PATTERN = re.compile(r'data "PassivesOnEquip" "([^"]+)"')
_STATUS_ON_EQUIP_PATTERN = re.compile(r'data "StatusOnEquip" "([^"]+)"')
_APPLY_STATUS_PATTERN = re.compile(r'ApplyStatus\(([^,)]+)(?:,([^,)]+))?')

# Constant set for ignored status target keywords (module level for performance)
_IGNORE_TARGETS = frozenset({"SELF", "TARGET", "SOURCE", "SWAP", ""})

# External definitions expected in base game or other modules; do not flag as missing
_EXTERNAL_SPELLS = frozenset({
    "Target_Darkness",
    "Target_FaerieFire",
    "Target_GOB_GoblinKing_ForceAttack_WeaponAttack",
    "Shout_WildShape_Dismiss",
    "Shout_ELDR_Aard",
    "Shout_ELDR_Igni",
    "Shout_ELDR_Quen",
})

_EXTERNAL_PASSIVES = frozenset({
    "MAG_Githborn_Mindcrusher_Greatsword_Passive",
    "MAG_LowHP_TemporaryHP_Passive",
    "MAG_Githborn_MagicEating_HalfPlate_Passive",
})

_EXTERNAL_STATUSES = frozenset({
    # Core combat statuses
    "BURNING", "POISONED", "BLEEDING", "STUNNED", "PRONE", "PARALYZED",
    "CHARMED", "FRIGHTENED", "BLINDNESS", "FEARED", "RESURRECTING", "INVISIBILITY",
    # Boss / narrative statuses
    "MOO_MAG_KETHERIC_HOWL_OF_THE_DEAD_AURA", "MOO_MAG_KETHERIC_STUPEFIED",
    "TAD_BLACK_HOLE_SLOW", "PRONE_THUNDEROUS_SMITE",
    # Spell/feature auras
    "PASSIVE_FIRE_SHIELD_WARM", "PASSIVE_FIRE_SHIELD_WARM_ATTACKER",
    "GLOBE_OF_INVULNERABILITY", "DOMINATE_PERSON",
    # Wild shape / companion statuses
    "OWLBEAR_WILDSHAPE_ENRAGE", "RAGE_STOP_REMOVE", "RAGE_ENDED",
    "WILDSHAPE_BADGER_REMOVE_VFX", "WILDSHAPE_CAT_REMOVE_VFX",
    "WILDSHAPE_SABERTOOTH_TIGER_REMOVE_VFX", "WILDSHAPE_OWLBEAR_REMOVE_VFX",
    "WILDSHAPE_BEAR_POLAR_REMOVE_VFX", "REGENERATION_SABERTOOTH",
    # Crowd control / debuffs used by Eldertide spells
    "PRONE", "PARALYZED", "PRONE_THUNDEROUS_SMITE",
})
class ParsedData:
    """Container for all parsed data from directory."""

    def __init__(self):
        self.spells = {}
        self.passives = {}
        self.statuses = {}
        self.uuids = defaultdict(list)
        self.spell_refs = []
        self.passive_refs = []
        self.status_refs = []


def parse_directory_single_pass(directory: str, collect_refs: bool = True, collect_uuids: bool = True) -> ParsedData:
    """Parse all files once and extract required info."""

    data = ParsedData()
    path = Path(directory)
    txt_files = list(path.rglob("*.txt"))
    total_files = len(txt_files)

    if total_files == 0:
        return data

    print(f"📂 Parsing {total_files} file(s)...")

    for idx, file_path in enumerate(txt_files, 1):
        if idx % 5 == 0 or idx == total_files:
            print(f"   Progress: {idx}/{total_files} files processed...")

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                lines = f.readlines()

            current_entry = ""
            current_entry_line = 0

            for i, line in enumerate(lines):
                stripped = line.strip()

                match = _ENTRY_PATTERN.match(stripped)
                if match:
                    current_entry = match.group(1)
                    current_entry_line = i + 1

                    end_idx = min(i + 5, len(lines))
                    for j in range(i, end_idx):
                        line_content = lines[j]
                        if 'type "SpellData"' in line_content:
                            data.spells[current_entry] = (str(file_path), current_entry_line)
                            break
                        if 'type "PassiveData"' in line_content:
                            data.passives[current_entry] = (str(file_path), current_entry_line)
                            break
                        if 'type "StatusData"' in line_content:
                            data.statuses[current_entry] = (str(file_path), current_entry_line)
                            break

                match = _UUID_PATTERN.match(stripped)
                if match and collect_uuids:
                    uuid = match.group(1)
                    data.uuids[uuid].append((str(file_path), i + 1, current_entry))

                if not collect_refs:
                    continue

                for spell_match in _UNLOCK_SPELL_PATTERN.finditer(line):
                    spell_name = spell_match.group(1)
                    data.spell_refs.append((str(file_path), i + 1, current_entry, spell_name))

                passive_match = _PASSIVES_ON_EQUIP_PATTERN.match(stripped)
                if passive_match:
                    passives_str = passive_match.group(1)
                    data.passive_refs.append((str(file_path), i + 1, current_entry, passives_str))

                status_match = _STATUS_ON_EQUIP_PATTERN.match(stripped)
                if status_match:
                    status_name = status_match.group(1)
                    data.status_refs.append((str(file_path), i + 1, current_entry, status_name))

                for apply_match in _APPLY_STATUS_PATTERN.finditer(line):
                    param1 = apply_match.group(1)
                    param2 = apply_match.group(2) if apply_match.lastindex and apply_match.lastindex >= 2 else None

                    data.status_refs.append((str(file_path), i + 1, current_entry, param1))
                    if param2:
                        data.status_refs.append((str(file_path), i + 1, current_entry, param2))

        except Exception:
            continue

    return data


class ReferenceError:
    def __init__(self, file_path: str, line_num: int, entry_name: str, ref_type: str, ref_name: str, message: str):
        self.file_path = file_path
        self.line_num = line_num
        self.entry_name = entry_name
        self.ref_type = ref_type
        self.ref_name = ref_name
        self.message = message

    def __str__(self) -> str:
        return (
            f"❌ {self.file_path}:{self.line_num} - {self.entry_name}\n"
            f"   Reference Type: {self.ref_type}\n"
            f"   Missing: {self.ref_name}\n"
            f"   Error: {self.message}\n"
        )


def validate_spell_references(parsed_data: ParsedData) -> List[ReferenceError]:
    errors: List[ReferenceError] = []

    for file_path, line_num, entry_name, spell_name in parsed_data.spell_refs:
        if spell_name in _EXTERNAL_SPELLS:
            continue
        if spell_name not in parsed_data.spells:
            errors.append(
                ReferenceError(
                    file_path,
                    line_num,
                    entry_name,
                    "UnlockSpell",
                    spell_name,
                    f"Spell '{spell_name}' is referenced but not defined",
                )
            )

    return errors


def validate_passive_references(parsed_data: ParsedData) -> List[ReferenceError]:
    errors: List[ReferenceError] = []

    for file_path, line_num, entry_name, passives_str in parsed_data.passive_refs:
        if not passives_str:
            continue

        passive_list = [p.strip() for p in passives_str.split(";")]

        for passive_name in passive_list:
            if not passive_name:
                continue
            if passive_name in _EXTERNAL_PASSIVES:
                continue
            if passive_name not in parsed_data.passives:
                errors.append(
                    ReferenceError(
                        file_path,
                        line_num,
                        entry_name,
                        "PassivesOnEquip",
                        passive_name,
                        f"Passive '{passive_name}' is referenced but not defined",
                    )
                )

    return errors


def validate_status_references(parsed_data: ParsedData) -> List[ReferenceError]:
    errors: List[ReferenceError] = []

    for file_path, line_num, entry_name, status_name in parsed_data.status_refs:
        status_name = status_name.strip().strip("'\"")

        if not status_name or status_name in _IGNORE_TARGETS or status_name.isdigit():
            continue
        if status_name in _EXTERNAL_STATUSES:
            continue
        if status_name not in parsed_data.statuses:
            errors.append(
                ReferenceError(
                    file_path,
                    line_num,
                    entry_name,
                    "Status",
                    status_name,
                    f"Status '{status_name}' is referenced but not defined",
                )
            )

    return errors


def validate_uuid_uniqueness(parsed_data: ParsedData) -> List[ReferenceError]:
    errors: List[ReferenceError] = []

    for uuid, locations in parsed_data.uuids.items():
        if len(locations) > 1:
            for file_path, line_num, entry_name in locations:
                errors.append(
                    ReferenceError(
                        file_path,
                        line_num,
                        entry_name,
                        "UUID",
                        uuid,
                        f"UUID '{uuid}' is used {len(locations)} times (must be unique)",
                    )
                )

    return errors


def merge_definitions(target: ParsedData, source: ParsedData) -> None:
    target.spells.update(source.spells)
    target.passives.update(source.passives)
    target.statuses.update(source.statuses)


def validate_directory(directory: str, include_dirs: List[str]) -> List[ReferenceError]:
    all_errors: List[ReferenceError] = []

    print("🔍 Parsing all files (single pass)...")
    parsed_data = parse_directory_single_pass(directory)

    for extra in include_dirs:
        if not os.path.isdir(extra):
            print(f"⚠️  Skipping include dir (not found): {extra}")
            continue
        print(f"➕ Including definitions from: {extra}")
        include_data = parse_directory_single_pass(extra, collect_refs=False, collect_uuids=False)
        merge_definitions(parsed_data, include_data)

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


def main() -> None:
    parser = argparse.ArgumentParser(description="BG3 Cross-Reference Validator")
    parser.add_argument("target", help="Path to mod directory to validate")
    parser.add_argument(
        "--include",
        nargs="*",
        default=[],
        help="Optional additional directories to pull definitions from (vanilla dumps, compatibility mods).",
    )
    args = parser.parse_args()

    target = args.target

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

    errors = validate_directory(target, args.include)

    if errors:
        print("=" * 70)
        print("REFERENCE ERRORS")
        print("=" * 70)
        print()
        for error in errors:
            print(error)

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

    print("✅ Validation PASSED - All references valid!")
    sys.exit(0)


if __name__ == "__main__":
    main()
