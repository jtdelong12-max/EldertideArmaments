#!/usr/bin/env python3
"""
BG3 Data File Optimizer

This script optimizes BG3 mod data files by:
- Removing excessive blank lines
- Standardizing line endings
- Removing trailing whitespace
- Preserving structure and readability

Usage:
    python3 optimize_data_files.py <path_to_directory> [--dry-run]

Example:
    python3 optimize_data_files.py Public/EldertideArmament/Stats/Generated/Data/ --dry-run
    python3 optimize_data_files.py Public/EldertideArmament/Stats/Generated/Data/
"""

import sys
import os
import re
from pathlib import Path
from typing import List, Tuple

def optimize_file(file_path: str, dry_run: bool = False) -> Tuple[int, int, int]:
    """Optimize a single data file.
    
    Returns:
        Tuple of (original_lines, optimized_lines, blank_lines_removed)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"❌ Error reading {file_path}: {e}")
        return 0, 0, 0
    
    original_line_count = len(lines)
    optimized_lines = []
    blank_lines_removed = 0
    consecutive_blanks = 0
    
    for line in lines:
        # Remove trailing whitespace but preserve line structure
        stripped = line.rstrip()
        
        # Track consecutive blank lines
        if not stripped:
            consecutive_blanks += 1
            # Allow maximum 1 consecutive blank line for readability
            if consecutive_blanks <= 1:
                optimized_lines.append('')
            else:
                blank_lines_removed += 1
        else:
            consecutive_blanks = 0
            optimized_lines.append(stripped)
    
    # Remove trailing blank lines at end of file
    while optimized_lines and not optimized_lines[-1]:
        optimized_lines.pop()
        blank_lines_removed += 1
    
    optimized_line_count = len(optimized_lines)
    
    # Write optimized content if not dry run
    if not dry_run and (original_line_count != optimized_line_count or blank_lines_removed > 0):
        try:
            with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
                f.write('\n'.join(optimized_lines))
                if optimized_lines:  # Add final newline if file is not empty
                    f.write('\n')
        except Exception as e:
            print(f"❌ Error writing {file_path}: {e}")
            return original_line_count, original_line_count, 0
    
    return original_line_count, optimized_line_count, blank_lines_removed

def optimize_directory(directory: str, dry_run: bool = False) -> None:
    """Optimize all .txt files in a directory."""
    path = Path(directory)
    
    if not path.exists():
        print(f"❌ Error: Path does not exist: {directory}")
        return
    
    # Find all .txt files
    txt_files = list(path.rglob("*.txt"))
    
    if not txt_files:
        print(f"❌ No .txt files found in {directory}")
        return
    
    print("="*70)
    print("BG3 Data File Optimizer")
    print("="*70)
    print(f"Directory: {directory}")
    print(f"Mode: {'DRY RUN (no changes)' if dry_run else 'OPTIMIZATION (files will be modified)'}")
    print(f"Files found: {len(txt_files)}")
    print()
    
    total_original_lines = 0
    total_optimized_lines = 0
    total_blank_lines_removed = 0
    files_modified = 0
    
    for txt_file in txt_files:
        file_size_kb = txt_file.stat().st_size / 1024
        print(f"📄 Processing: {txt_file.name} ({file_size_kb:.1f} KB)")
        
        original, optimized, blanks = optimize_file(str(txt_file), dry_run)
        
        total_original_lines += original
        total_optimized_lines += optimized
        total_blank_lines_removed += blanks
        
        if original != optimized or blanks > 0:
            files_modified += 1
            reduction = original - optimized
            percentage = (reduction / original * 100) if original > 0 else 0
            print(f"   Lines: {original} → {optimized} (removed {reduction}, {percentage:.1f}%)")
            print(f"   Blank lines removed: {blanks}")
        else:
            print(f"   ✅ Already optimized")
        print()
    
    # Print summary
    print("="*70)
    print("OPTIMIZATION SUMMARY")
    print("="*70)
    print(f"Files processed: {len(txt_files)}")
    print(f"Files modified: {files_modified}")
    print(f"Total lines before: {total_original_lines}")
    print(f"Total lines after: {total_optimized_lines}")
    print(f"Lines removed: {total_original_lines - total_optimized_lines}")
    print(f"Blank lines removed: {total_blank_lines_removed}")
    
    if total_original_lines > 0:
        reduction_pct = ((total_original_lines - total_optimized_lines) / total_original_lines * 100)
        print(f"Overall reduction: {reduction_pct:.2f}%")
    
    print()
    
    if dry_run:
        print("🔍 DRY RUN completed - No files were modified")
        print("💡 Run without --dry-run to apply changes")
    else:
        print("✅ Optimization completed successfully")
        if files_modified > 0:
            print("💾 Files have been modified - review changes before committing")

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    directory = sys.argv[1]
    dry_run = '--dry-run' in sys.argv
    
    optimize_directory(directory, dry_run)

if __name__ == "__main__":
    main()
