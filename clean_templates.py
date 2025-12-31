"""
Quick script to clean merged.lsf.lsx - removes all character templates.
Run this from the repository root.
"""

import xml.etree.ElementTree as ET
from pathlib import Path

# File path
merged_file = Path("Public/EldertideArmament/RootTemplates/_merged.lsf.lsx")

if not merged_file.exists():
    print(f"ERROR: File not found: {merged_file}")
    print(f"Current directory: {Path.cwd()}")
    exit(1)

print(f"Reading: {merged_file}")
print(f"File size: {merged_file.stat().st_size:,} bytes")

# Parse XML
tree = ET.parse(merged_file)
root = tree.getroot()

# Find the Templates region
templates_region = root.find(".//region[@id='Templates']")
templates_node = templates_region.find(".//node[@id='Templates']")
children = templates_node.find("children")

# Find and remove character templates
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

# Report
print(f"\n{'='*60}")
print(f"Results:")
print(f"  ✓ Templates kept: {kept_count}")
print(f"  ✗ Character templates removed: {removed_count}")
print(f"{'='*60}")

if character_names:
    print(f"\nRemoved character templates ({len(character_names)}):")
    for name in sorted(character_names)[:20]:  # Show first 20
        print(f"  - {name}")
    if len(character_names) > 20:
        print(f"  ... and {len(character_names) - 20} more")

# Create backup
backup_file = merged_file.parent / "_merged.lsf.lsx.backup"
print(f"\nCreating backup: {backup_file}")
import shutil
shutil.copy2(merged_file, backup_file)

# Save cleaned file
print(f"Saving cleaned file...")
tree.write(merged_file, encoding='utf-8', xml_declaration=True)

new_size = merged_file.stat().st_size
print(f"\n✓ COMPLETE!")
print(f"  New file size: {new_size:,} bytes")
print(f"  Backup: {backup_file}")
