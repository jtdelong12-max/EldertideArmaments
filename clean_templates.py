"""
Script to clean _merged.lsf.lsx - removes all character templates.
Run this from the repository root.
"""

import xml.etree.ElementTree as ET
from pathlib import Path
import shutil

merged_file = Path("Public/EldertideArmament/RootTemplates/_merged.lsf.lsx")

if not merged_file.exists():
    print(f"ERROR: File not found: {merged_file}")
    exit(1)

print(f"Reading: {merged_file}")
print(f"File size: {merged_file.stat().st_size:,} bytes")

# Create backup BEFORE parsing
backup_file = merged_file.with_suffix('.lsf.lsx.backup')
print(f"\nCreating backup: {backup_file}")
shutil.copy2(merged_file, backup_file)
print("Backup created successfully")

tree = ET.parse(merged_file)
root = tree.getroot()

templates_region = root.find(".//region[@id='Templates']")
templates_node = templates_region.find(".//node[@id='Templates']")
children = templates_node.find("children")

removed_count = 0
kept_count = 0
character_names = []

game_objects = list(children.findall("node[@id='GameObjects']"))

print(f"\nScanning {len(game_objects)} GameObjects templates...")

for obj in game_objects:
    type_attr = obj.find("./attribute[@id='Type']")
    
    if type_attr is not None and type_attr.get('value') == 'character':
        name_attr = obj.find("./attribute[@id='Name']")
        name = name_attr.get('value') if name_attr is not None else "Unknown"
        character_names.append(name)
        children.remove(obj)
        removed_count += 1
    else:
        kept_count += 1

print(f"\n{'='*60}")
print(f"Results:")
print(f"  Templates kept: {kept_count}")
print(f"  Character templates removed: {removed_count}")
print(f"{'='*60}")

if character_names:
    print(f"\nRemoved character templates ({len(character_names)}):")
    for name in sorted(character_names)[:25]:
        print(f"  - {name}")
    if len(character_names) > 25:
        print(f"  ... and {len(character_names) - 25} more")

print(f"\nSaving cleaned file...")
tree.write(merged_file, encoding='utf-8', xml_declaration=True)

new_size = merged_file.stat().st_size
old_size = backup_file.stat().st_size
reduction = old_size - new_size
percent = (reduction / old_size) * 100

print(f"\n{'='*60}")
print(f"CLEANUP COMPLETE!")
print(f"{'='*60}")
print(f"  Original size: {old_size:,} bytes")
print(f"  New size: {new_size:,} bytes")
print(f"  Reduced by: {reduction:,} bytes ({percent:.1f}%)")
print(f"  Backup saved: {backup_file}")
