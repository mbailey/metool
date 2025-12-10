---
name: metool
description: Package management system for organizing, installing, and managing shell scripts, dotfiles, and development tools. This skill should be used when installing, listing, or working with metool packages and modules, or when needing to understand metool commands and package structure.
---

# Metool Package Management

## Overview

Metool (mt) is a modular system for managing shell environments through packages. It provides a "propagation tray for ideas" - a place where scripts, functions, and tools can be organized, tested, and evolved before becoming standalone projects.

## When to Use This Skill

Use this skill when:
- Installing or listing metool packages
- Working with metool commands (install, cd, edit, etc.)
- Understanding package structure and conventions
- Setting up configuration files or dotfiles via metool

For creating new packages or adding SKILL.md files, load the detailed docs:
- `docs/skills/creating-packages.md` - Package creation guide
- `docs/skills/creating-skills.md` - SKILL.md creation guide

## Package Structure

Every metool package follows this standard structure:

```
package-name/
├── README.md        # Package documentation (REQUIRED)
├── SKILL.md         # Claude Code skill (optional)
├── bin/            # Executable scripts (symlinked to ~/.metool/bin)
├── shell/          # Shell functions, aliases, completions
├── config/         # Config files (use dot- prefix for dotfiles)
├── lib/            # Library functions (sourced, not executed)
├── libexec/        # Helper scripts (not in PATH)
└── docs/           # Additional documentation
```

### Dotfile Naming

Files in `config/` use `dot-` prefix which gets converted:
- `config/dot-bashrc` → `~/.bashrc`
- `config/dot-gitconfig` → `~/.gitconfig`
- `config/dot-config/tool/` → `~/.config/tool/`

## Common Commands

### Package Management

```bash
# Add package from module to working set
mt package add module/package-name

# Install package (create symlinks)
mt package install package-name

# List packages in working set
mt package list

# Find a specific package
mt package list | grep -w package-name

# Validate package structure
mt package validate package-name
```

### Module Management

```bash
# List modules in working set
mt module list
```

### Navigation and Editing

```bash
mt cd                    # Go to metool root
mt cd package-name       # Go to package directory
mt edit function-name    # Edit a shell function
mt edit command-name     # Edit an executable
mt components            # List all components
mt reload                # Reload shell configuration
```

### Dependencies

```bash
mt deps              # Check dependencies
mt deps --install    # Auto-install on macOS
```

## Prerequisites

Metool requires:
- **GNU coreutils** (for `realpath`)
  - macOS: `brew install coreutils`
  - Ubuntu: Usually pre-installed
- **GNU Stow 2.4.0+** (for `mt install`)
  - macOS: `brew install stow`
  - Ubuntu: `apt install stow`

## Troubleshooting

### Conflicts During Installation

When installing config files that already exist:
1. The command shows which files conflict
2. You're prompted to remove existing files
3. If accepted, conflicting file is removed and installation retries
4. Broken symlinks are identified and can be safely removed

## Creating Packages and Skills

For detailed guidance on creating new metool packages or adding SKILL.md files to existing packages, read:

- **docs/skills/creating-packages.md** - Complete package creation guide with examples
- **docs/skills/creating-skills.md** - Guide for creating effective SKILL.md files

Use the Read tool to load these files when needed.

## Additional Documentation

For more detailed information:
- `docs/conventions/package-structure.md` - Complete package structure conventions
- `docs/reference/commands/` - Individual command documentation
- `docs/guides/repository-management.md` - Managing repositories with metool
- `docs/systemd.md` - Systemd service management
