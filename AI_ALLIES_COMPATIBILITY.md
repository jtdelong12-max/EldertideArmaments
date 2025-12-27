# AI-Allies Compatibility Guide

This document outlines how the Eldertide Armaments repository is structured to be compatible with the [AI-Allies](https://github.com/jtdelong12-max/AI-Allies) repository approach.

## Overview

Eldertide Armaments follows the AI-Allies methodology for organizing and validating Baldur's Gate 3 modding data. This ensures consistency, maintainability, and ease of integration with AI-powered tools and workflows.

## Compatibility Features

### 1. Structured Reference Data

The `reference/` directory mirrors AI-Allies' approach to organizing knowledge:

```
reference/
├── vanilla_data/          # Organized BG3 reference data
│   ├── spells/           # Spell examples and patterns
│   ├── items/            # Item/armor templates
│   ├── status_effects/   # Status effect references
│   ├── passives/         # Passive ability examples
│   └── Gustav/           # Vanilla game data structure
└── scripts/              # Validation and automation tools
```

**Compatibility Benefit**: Structured data enables AI-powered search, validation, and code generation tools to understand and work with the mod's content.

### 2. Validation Scripts

Python scripts for automated validation:
- `validate_spells.py` - Validates spell definitions
- `validate_items.py` - Validates item/armor definitions
- `validate_references.py` - Checks cross-references
- `benchmark_validation.py` - Performance testing
- `optimize_data_files.py` - Data optimization

**Compatibility Benefit**: Scripts can be integrated into AI-Allies workflows for automated quality assurance and continuous integration.

### 3. Documentation Structure

Comprehensive markdown documentation:
- Clear hierarchy and organization
- Cross-referenced content
- Searchable and indexable
- Machine-readable metadata

**Compatibility Benefit**: Documentation structure allows AI tools to understand context, relationships, and usage patterns.

### 4. Semantic Organization

Data is organized by:
- **Type** (spells, items, statuses, passives)
- **Function** (validation, reference, documentation)
- **Scope** (vanilla data vs. mod data)

**Compatibility Benefit**: Semantic organization enables better AI understanding and retrieval of relevant information.

## Integration Points

### For AI-Allies Tools

This repository provides:

1. **Reference Knowledge Base**: Vanilla BG3 data examples that AI tools can use as ground truth
2. **Validation Rules**: Codified patterns and constraints for BG3 modding
3. **Documentation Corpus**: Rich text for training or context in AI-powered assistants
4. **Cross-Reference Network**: Relationships between game entities (spells, items, statuses)

### For Semantic Search

The structure supports semantic search by:

- **Clear naming conventions**: Entities are named descriptively
- **Comprehensive documentation**: Each component has detailed explanations
- **Contextual relationships**: Cross-references show how components interact
- **Examples and patterns**: Reference data provides concrete usage examples

### For AI Code Generation

The repository supports AI code generation through:

- **Template patterns**: Vanilla data shows correct syntax
- **Validation rules**: Scripts define valid parameter ranges and values
- **Common patterns**: Reference data documents best practices
- **Error examples**: Validation scripts show common mistakes to avoid

## Data Format Standards

### File Organization

All data files follow these conventions:

```
Public/EldertideArmament/Stats/Generated/Data/
├── Armor.txt              # Item definitions
├── Spells_*.txt           # Spell definitions by category
├── Passive_*.txt          # Passive abilities
└── Status_*.txt           # Status effects
```

### Naming Conventions

- **Entries**: `ELDER_<Type>_<Name>` (e.g., `ELDER_Ring_AstralChampion`)
- **Spells**: `ELDER_<SpellType>_<Name>` (e.g., `ELDER_Projectile_SkywardSoar`)
- **Statuses**: `ELDER_<StatusName>` (e.g., `ELDER_DRAGON_HERITAGE_ACTIVE`)
- **Passives**: `Passive_ELDER_<Name>` (e.g., `Passive_ELDER_DraconicRetaliation`)

**Compatibility Benefit**: Consistent naming enables pattern-based search and validation.

### Property Documentation

All properties include:
- Valid value ranges
- Data types
- Required vs optional
- Common patterns
- Examples from vanilla data

**Compatibility Benefit**: Enables AI tools to generate valid BG3 mod data.

## Validation and Quality Assurance

### Automated Validation

The repository includes comprehensive validation that checks:

1. **Syntax Validation**
   - Property names and values
   - Data type correctness
   - Format consistency

2. **Semantic Validation**
   - Cross-reference integrity
   - Logical consistency
   - Game rule compliance

3. **Performance Validation**
   - File size optimization
   - Load time efficiency
   - Memory usage

### Integration with CI/CD

Validation scripts can be integrated into:
- GitHub Actions workflows
- Pre-commit hooks
- Automated testing pipelines
- AI-powered review tools

**Compatibility Benefit**: Ensures quality while enabling automated workflows.

## Use Cases with AI-Allies

### 1. AI-Powered Modding Assistant

AI-Allies can use this repository to:
- Answer questions about BG3 modding patterns
- Generate mod content based on templates
- Validate user-created content
- Suggest improvements and optimizations

### 2. Knowledge Base Integration

This repository serves as:
- Training data for AI models
- Reference corpus for semantic search
- Validation ground truth
- Example library for code generation

### 3. Automated Code Review

AI tools can:
- Check submitted changes against patterns
- Suggest improvements based on best practices
- Identify potential bugs or incompatibilities
- Recommend optimizations

### 4. Interactive Documentation

AI-Allies can provide:
- Natural language queries over documentation
- Context-aware help and suggestions
- Interactive examples and tutorials
- Personalized learning paths

## Technical Integration Details

### Data Access

The repository provides multiple access patterns:

```python
# Direct file access
with open('reference/vanilla_data/spells/REFERENCE_Spells.txt') as f:
    reference_data = f.read()

# Script-based validation
from reference.scripts import validate_spells
results = validate_spells.validate_file('path/to/spells.txt')

# Pattern matching
import re
spell_pattern = re.compile(r'new entry "ELDER_\w+_\w+"')
```

### API Compatibility

The validation scripts follow a consistent API:

```python
def validate_file(filepath: str) -> Dict[str, List[str]]:
    """
    Returns:
        {
            'valid': [list of valid entries],
            'errors': [list of error messages],
            'warnings': [list of warning messages]
        }
    """
```

### Metadata Format

Each reference file includes metadata:

```
# REFERENCE: Spells
# VERSION: 1.0
# BG3_PATCH: Patch 8 (Build 6758295)
# LAST_UPDATED: 2025-12-27
# PURPOSE: Spell definition reference and validation
```

**Compatibility Benefit**: Metadata enables versioning, tracking, and compatibility checks.

## Best Practices for AI-Allies Integration

### 1. Keep Reference Data Current

- Update reference files when BG3 patches
- Document changes in CHANGELOG.md
- Version reference data appropriately
- Test validation scripts after updates

### 2. Maintain Clear Documentation

- Use consistent markdown formatting
- Include code examples
- Cross-reference related content
- Keep documentation in sync with code

### 3. Follow Naming Conventions

- Use consistent prefixes (ELDER_)
- Follow vanilla BG3 patterns
- Document naming rules
- Validate names in scripts

### 4. Enable Machine Readability

- Use structured data formats
- Include metadata headers
- Follow consistent patterns
- Provide schemas where applicable

### 5. Support Automation

- Write testable validation scripts
- Use clear error messages
- Enable CI/CD integration
- Provide usage examples

## Future Enhancements

### Planned Improvements

1. **Enhanced Metadata**
   - JSON schema definitions
   - OpenAPI-style documentation
   - Structured relationship graphs

2. **AI Training Data**
   - Curated example sets
   - Labeled training data
   - Classification taxonomies

3. **Integration APIs**
   - REST API for validation
   - GraphQL for relationships
   - WebSocket for real-time validation

4. **Interactive Tools**
   - Web-based validation UI
   - Visual relationship explorer
   - Interactive documentation

## Resources

### Related Projects

- [AI-Allies](https://github.com/jtdelong12-max/AI-Allies) - AI-powered BG3 modding assistant
- [BG3 Mod Fixer](https://www.nexusmods.com/baldursgate3/mods/141) - Compatibility tool
- [BG3 Script Extender](https://github.com/Norbyte/bg3se) - Advanced modding

### Documentation

- [VALIDATION_GUIDE.md](VALIDATION_GUIDE.md) - Comprehensive validation documentation
- [reference/README.md](reference/README.md) - Reference structure guide
- [DOCUMENTATION.md](DOCUMENTATION.md) - Complete documentation overview

### Community

- [BG3 Modding Discord](https://discord.gg/bg3mods)
- [Nexus Mods Forums](https://forums.nexusmods.com/index.php?/forum/5264-baldurs-gate-3/)

## Contributing

To maintain AI-Allies compatibility:

1. Follow existing patterns and conventions
2. Update documentation when adding features
3. Run validation scripts before committing
4. Include tests for new validation rules
5. Document AI integration points

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Version History

- **1.0.0** (2025-12-27): Initial AI-Allies compatibility structure
  - Updated repository references
  - Created compatibility documentation
  - Established integration patterns

## License

This compatibility structure is part of the Eldertide Armaments project and follows the same licensing terms. See the Nexus Mods page for details.

---

*For questions about AI-Allies integration, please open an issue on GitHub or reach out through the modding community channels.*
