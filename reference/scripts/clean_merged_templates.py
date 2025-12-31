"""
Clean _merged.lsf.lsx by removing character templates.

This script removes all character templates (Type="character") from the merged
root templates file, keeping only items, projectiles, and objects.
"""

import xml.etree.ElementTree as ET
import sys
from pathlib import Path

def clean_merged_file(input_file, output_file=None, dry_run=False):
    """Remove all character templates from merged.lsf.lsx file."""
    
    if output_file is None:
        output_file = input_file
    
    print(f"Reading: {input_file}")
    
    # Parse XML
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    # Find the Templates region
    templates_region = root.find(".//region[@id='Templates']")
    if templates_region is None:
        print("ERROR: Could not find Templates region")
        return False
    
    templates_node = templates_region.find(".//node[@id='Templates']")
    if templates_node is None:
        print("ERROR: Could not find Templates node")
        return False
    
    children = templates_node.find("children")
    if children is None:
        print("ERROR: Could not find children node")
        return False
    
    # Find and remove character templates
    removed_count = 0
    kept_count = 0
    character_names = []
    
    game_objects = list(children.findall("node[@id='GameObjects']"))
    
    for obj in game_objects:
        # Find Type attribute
        type_attr = obj.find("./attribute[@id='Type']")
        
        if type_attr is not None and type_attr.get('value') == 'character':
            # Get name for reporting
            name_attr = obj.find("./attribute[@id='Name']")
            name = name_attr.get('value') if name_attr is not None else "Unknown"
            character_names.append(name)
            
            if not dry_run:
                children.remove(obj)
            removed_count += 1
        else:
            kept_count += 1
    
    # Report findings
    print(f"\n{'DRY RUN - ' if dry_run else ''}Results:")
    print(f"  Templates kept: {kept_count}")
    print(f"  Character templates removed: {removed_count}")
    
    if character_names:
        print(f"\nRemoved character templates:")
        for name in sorted(character_names):
            print(f"  - {name}")
    
    # Save if not dry run
    if not dry_run:
        print(f"\nSaving cleaned file to: {output_file}")
        tree.write(output_file, encoding='utf-8', xml_declaration=True)
        print("✓ File saved successfully")
    else:
        print("\n(Dry run - no changes made)")
    
    return True

def main():
    """Main entry point."""
    
    # Get script directory
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent
    
    # Define paths
    merged_file = repo_root / "Public" / "EldertideArmament" / "RootTemplates" / "_merged.lsf.lsx"
    backup_file = merged_file.parent / "_merged.lsf.lsx.backup"
    
    if not merged_file.exists():
        print(f"ERROR: File not found: {merged_file}")
        return 1
    
    # Parse arguments
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv
    create_backup = "--no-backup" not in sys.argv
    
    if dry_run:
        print("=" * 60)
        print("DRY RUN MODE - No changes will be made")
        print("=" * 60)
    
    # Create backup
    if create_backup and not dry_run:
        print(f"Creating backup: {backup_file}")
        import shutil
        shutil.copy2(merged_file, backup_file)
        print("✓ Backup created\n")
    
    # Clean the file
    success = clean_merged_file(merged_file, dry_run=dry_run)
    
    if success and not dry_run:
        print("\n" + "=" * 60)
        print("CLEANUP COMPLETE!")
        print("=" * 60)
        print(f"Backup saved to: {backup_file}")
        print(f"Cleaned file: {merged_file}")
        print("\nNext steps:")
        print("1. Review the changes in the file")
        print("2. Test the mod in-game")
        print("3. Delete backup if satisfied: _merged.lsf.lsx.backup")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
