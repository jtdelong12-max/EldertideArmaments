#!/usr/bin/env python3
"""
Example script demonstrating how AI-Allies can integrate with this repository.

This script shows how to:
1. Load repository metadata
2. Access reference data
3. Use validation scripts programmatically
4. Query structured information

Usage:
    python3 ai_allies_integration_example.py
"""

import json
import os
from pathlib import Path


def get_repo_root():
    """Find the repository root directory."""
    current = Path.cwd()
    # Look for .ai-allies-metadata.json
    for parent in [current] + list(current.parents):
        metadata_path = parent / ".ai-allies-metadata.json"
        if metadata_path.exists():
            return parent
    # Fallback: assume we're in reference/scripts
    if current.name == "scripts":
        return current.parent.parent
    return current


def load_metadata():
    """Load AI-Allies metadata from the repository."""
    repo_root = get_repo_root()
    metadata_path = repo_root / ".ai-allies-metadata.json"
    with open(metadata_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def list_reference_data():
    """List available reference data files."""
    metadata = load_metadata()
    repo_root = get_repo_root()
    ref_path = repo_root / metadata['structure']['reference_data']['path']
    
    print("📚 Available Reference Data:")
    print("=" * 60)
    
    for category in metadata['structure']['reference_data']['categories']:
        category_path = ref_path / category
        if category_path.exists():
            files = list(category_path.rglob("*.txt"))
            print(f"\n{category.upper()}:")
            for file in files[:5]:  # Show first 5 files
                rel_path = file.relative_to(repo_root)
                size_kb = file.stat().st_size / 1024
                print(f"  - {rel_path} ({size_kb:.1f} KB)")
            if len(files) > 5:
                print(f"  ... and {len(files) - 5} more files")


def list_validation_scripts():
    """List available validation scripts and their purposes."""
    metadata = load_metadata()
    
    print("\n🔍 Validation Scripts:")
    print("=" * 60)
    
    for script in metadata['structure']['validation_scripts']['scripts']:
        print(f"\n{script['name']}:")
        print(f"  Purpose: {script['purpose']}")
        print(f"  Usage: {script['usage']}")


def show_naming_conventions():
    """Display naming conventions used in the repository."""
    metadata = load_metadata()
    conventions = metadata['naming_conventions']
    
    print("\n📋 Naming Conventions:")
    print("=" * 60)
    print(f"Prefix: {conventions['prefix']}")
    print("\nPatterns:")
    for key, pattern in conventions['patterns'].items():
        print(f"  {key}: {pattern}")
    
    print("\nExamples:")
    for key, example in conventions['examples'].items():
        print(f"  {key}: {example}")


def show_ai_integration_capabilities():
    """Display AI integration capabilities."""
    metadata = load_metadata()
    ai_integration = metadata['ai_integration']
    
    print("\n🤖 AI Integration Capabilities:")
    print("=" * 60)
    
    print("\nSemantic Search:")
    for key, value in ai_integration['semantic_search'].items():
        status = "✅" if value else "❌"
        print(f"  {status} {key.replace('_', ' ').title()}")
    
    print("\nCode Generation:")
    for key, value in ai_integration['code_generation'].items():
        status = "✅" if value else "❌"
        print(f"  {status} {key.replace('_', ' ').title()}")
    
    print("\nAutomated Validation:")
    for key, value in ai_integration['automated_validation'].items():
        status = "✅" if value else "❌"
        print(f"  {status} {key.replace('_', ' ').title()}")


def query_mod_components():
    """Query available mod components."""
    metadata = load_metadata()
    components = metadata['structure']['mod_data']['components']
    
    print("\n📦 Mod Components:")
    print("=" * 60)
    
    for component in components:
        print(f"\n{component['type']}:")
        print(f"  Path: {component['path']}")
        print(f"  Count: {component['count']}")
        print(f"  Categories: {', '.join(component['categories'])}")


def main():
    """Main entry point for the integration example."""
    print("╔════════════════════════════════════════════════════════════╗")
    print("║   AI-Allies Integration Example for Eldertide Armaments   ║")
    print("╚════════════════════════════════════════════════════════════╝")
    
    try:
        metadata = load_metadata()
        repo_info = metadata['repository']
        
        print(f"\n✅ Successfully loaded metadata for: {repo_info['name']}")
        print(f"   Owner: {repo_info['owner']}")
        print(f"   Type: {repo_info['type']}")
        print(f"   AI-Allies Compatible: {'Yes' if repo_info['compatibility']['ai_allies'] else 'No'}")
        
        # Show various information
        list_reference_data()
        list_validation_scripts()
        show_naming_conventions()
        query_mod_components()
        show_ai_integration_capabilities()
        
        print("\n" + "=" * 60)
        print("✅ Integration example completed successfully!")
        print("=" * 60)
        
    except FileNotFoundError as e:
        print(f"\n❌ Error: File not found - {e.filename}")
        print("Make sure you're running this script from the repository root")
    except json.JSONDecodeError as e:
        print(f"\n❌ Error: Invalid JSON in metadata file at line {e.lineno}")
        print(f"   {e.msg}")
    except KeyError as e:
        print(f"\n❌ Error: Missing expected key in metadata: {e}")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")


if __name__ == "__main__":
    main()
