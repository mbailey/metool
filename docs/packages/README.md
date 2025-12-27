# Packages

Metool packages are self-contained units of functionality that organize scripts, functions, configuration files, and documentation.

## Contents

- [structure.md](structure.md) - Package directory layout and conventions
- [symlinks.md](symlinks.md) - How GNU Stow creates symlinks during installation
- [creation.md](creation.md) - Step-by-step guide to creating a new package
- [python.md](python.md) - Python script conventions (uv, PEP 723)
- [naming.md](naming.md) - Package and script naming conventions
- [promotion.md](promotion.md) - Moving packages between modules

## Quick Reference

### Package Structure

```
package-name/
├── README.md        # Documentation (required)
├── SKILL.md         # Claude Code skill (optional)
├── bin/             # Executables → ~/.metool/bin/
├── shell/           # Functions, aliases → ~/.metool/shell/
├── config/          # Dotfiles → ~/
├── lib/             # Library functions (not symlinked)
├── libexec/         # Helper scripts (not in PATH)
└── docs/            # Additional documentation
```

### Essential Commands

```bash
mt package add module/package    # Add to working set
mt package install package-name  # Install (create symlinks)
mt cd package-name               # Navigate to package
```

## See Also

- [docs/skills/README.md](../skills/README.md) - Adding AI assistance to packages
- [docs/services/README.md](../services/README.md) - Service management packages
- [docs/commands/README.md](../commands/README.md) - Full command reference
