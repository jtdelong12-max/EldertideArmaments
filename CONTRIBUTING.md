# Contributing to Eldertide Armaments

Thank you for your interest in contributing to Eldertide Armaments! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

When reporting bugs, please include:

1. **Game Version**: BG3 version and patch number
2. **Mod Version**: Check `Mods/EldertideArmament/meta.lsx` for version
3. **Mod List**: Complete list of installed mods and load order
4. **Script Extender**: Whether BG3 Script Extender is installed
5. **Steps to Reproduce**: Clear steps to reproduce the issue
6. **Expected Behavior**: What should happen
7. **Actual Behavior**: What actually happens
8. **Screenshots**: If applicable, add screenshots to help explain

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

1. **Clear Description**: What feature you'd like to see
2. **Use Case**: Why this feature would be useful
3. **Examples**: Examples from other mods or games if applicable
4. **Balance Considerations**: How it fits with existing items

### Code Contributions

If you'd like to contribute code:

1. **Fork the Repository**: Create your own fork
2. **Create a Branch**: Use descriptive branch names (e.g., `fix-duplicate-items`, `add-new-ring`)
3. **Make Changes**: Keep changes focused and minimal
4. **Test Thoroughly**: Test in-game with various scenarios
5. **Document Changes**: Update README.md and CHANGELOG.md as needed
6. **Submit Pull Request**: Provide clear description of changes

### Modding Standards

When contributing to the mod files:

#### File Structure
- Keep LSX files properly formatted and indented
- Use consistent naming conventions
- Follow existing patterns in the codebase

#### Stats Files (.txt)
- Follow BG3 stats file syntax exactly
- Use proper inheritance with `using` keyword
- Avoid duplicate entries
- Test all stat changes in-game

#### Treasure Tables
- Use proper probability syntax (e.g., `"1,1"` for guaranteed, `"0,7;1,1"` for 70% chance)
- Document any new loot locations
- Maintain balance with existing loot

#### Localization
- Add entries to localization files for new items
- Use clear, descriptive names
- Include proper formatting for in-game tooltips

### Balance Guidelines

When adding or modifying items:

1. **Legendary Tier**: Items should feel powerful but not game-breaking
2. **Uniqueness**: Each item should offer distinct gameplay options
3. **Trade-offs**: Powerful effects should have meaningful costs or limitations
4. **Build Diversity**: Support multiple playstyles and character builds
5. **Progression**: Consider where items fit in game progression

### Testing Checklist

Before submitting changes:

- [ ] Item appears correctly in inventory
- [ ] Tooltips display properly
- [ ] Spells unlock when equipped
- [ ] Passive abilities function as intended
- [ ] Visual effects display correctly
- [ ] Item can be unequipped without issues
- [ ] No console errors or warnings
- [ ] Compatible with BG3 Mod Fixer
- [ ] Tested with clean save and existing save
- [ ] Tested in different game areas/scenarios

## Community Guidelines

- Be respectful and constructive
- Help other users troubleshoot issues
- Share your experiences and feedback
- Credit others' work appropriately
- Follow the Nexus Mods community guidelines

## Questions?

- Check the [README.md](README.md) for documentation
- Visit the [Nexus Mods page](https://www.nexusmods.com/baldursgate3/mods/3596) for discussions
- Check the Posts tab for community help

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

*Thank you for helping make Eldertide Armaments better!*
