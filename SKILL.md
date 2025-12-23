---
name: metool
description: Package management system for organizing, installing, and managing shell scripts, dotfiles, and development tools. This skill should be used when creating, modifying, reviewing, or installing metool packages, working with metool commands and package structure, or creating Claude Code skills for metool packages.
---

# Metool Package Management

## Overview

Metool (mt) is a modular system for managing shell environments through packages. It provides a "propagation tray for ideas" - a place where scripts, functions, and tools can be organized, tested, and evolved before becoming standalone projects.

## When to Use This Skill

Use this skill when:
- Creating new metool packages
- Installing or modifying metool packages
- Working with metool commands (install, cd, edit, etc.)
- Setting up configuration files or dotfiles via metool
- Creating or updating Claude Code skills for metool packages

## Quick Reference

### Package Structure

```
package-name/
├── README.md        # Required
├── SKILL.md         # Optional (enables AI assistance)
├── bin/             # Executables (symlinked to ~/.metool/bin)
├── shell/           # Functions, aliases, completions
├── config/          # Dotfiles (use dot- prefix)
├── lib/             # Library functions
├── libexec/         # Helper scripts (not in PATH)
└── docs/            # Additional documentation
```

For complete conventions, see @docs/conventions/package-structure.md

### Essential Commands

```bash
mt package add module/package    # Add to working set
mt package install package-name  # Install (create symlinks)
mt cd package-name               # Navigate to package
mt edit function-name            # Edit a function/script
mt reload                        # Reload after changes
```

For all commands, see @docs/reference/commands/README.md

### How mt Works

The `mt` command is a shell function (not a binary), which enables features like `mt cd` that change your current directory. Most functionality works through the function.

**Fallback binary**: When the shell function isn't available (e.g., calling from scripts, cron, or non-bash shells), use `bin/mt` directly. This binary wrapper sources the function and executes commands, but some features like directory changing won't affect the parent shell.

## Creating a Package

### Step 1: Create Structure

```bash
mkdir -p package-name/{bin,shell,config,lib}
```

### Step 2: Create README.md (Required)

```markdown
# Package Name

Brief description

## Installation

\`\`\`bash
mt package add module/package-name
mt package install package-name
\`\`\`

## Components

- `bin/tool-name` - Main tool
- `shell/functions` - Helper functions

## Usage

[Usage examples]
```

### Step 3: Add Components

**Executables (bin/):**
```bash
cat > package-name/bin/tool-name << 'EOF'
#!/usr/bin/env bash
# Tool description
EOF
chmod +x package-name/bin/tool-name
```

**Shell Functions (shell/):**
- `shell/functions` - Shell functions
- `shell/aliases` - Command aliases
- `shell/completions/` - Bash tab completion
- `shell/environment` - Environment exports
- `shell/path` - PATH modifications

**Dotfiles (config/):**
Use `dot-` prefix: `config/dot-bashrc` → `~/.bashrc`

See @docs/conventions/package-structure.md for full details.

### Step 4: Install

```bash
mt package add module/package-name
mt package install package-name
```

## Python Scripts

Use uv with PEP 723 inline script metadata:

```python
#!/usr/bin/env python
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests", "click"]
# ///

import requests
import click
# Script implementation
```

Scripts in `bin/` should have no `.py` extension.

## Service Packages

For packages managing systemd/launchd services, use the service package template.

See @docs/templates/service-package/README.md for:
- Cross-platform service management (Linux/macOS)
- Standard subcommands: install, start, stop, restart, status, logs
- Version detection and monitoring
- Complete shell aliases pattern

## Package Promotion

Promote packages from development to public modules safely.

### Compare Packages Between Modules

```bash
# See what differs
mt package diff tmux dev pub

# Show detailed content differences
mt package diff tmux dev pub --content

# Quiet mode for scripting
mt package diff tmux dev pub --quiet
```

### Promotion Workflow

1. **Compare** - `mt package diff <package> dev pub`
2. **Review** - Check for sensitive content (secrets, internal paths)
3. **Promote** - Copy approved files to target module
4. **Commit** - Commit changes in target module

See `docs/guides/package-promotion.md` for detailed workflow.

## Claude Code Skills

Packages can include a `SKILL.md` file to enable AI assistance. This creates human-AI collaborative infrastructure where:
- Humans get CLI tools, shell functions, and documentation
- AI gets procedural knowledge, workflows, and tool references

### SKILL.md Structure

```markdown
---
name: package-name
description: Brief explanation. This skill should be used when [scenarios].
---

# Package Name

## Overview
[What this skill enables]

## Workflows
[Step-by-step procedures with tool references]
```

### Key Points

- Use third-person in description ("This skill should be used when...")
- Keep under 5k words; move details to docs/
- Reference package tools by command name (they're in PATH after install)
- Focus on procedural knowledge Claude cannot infer

See @docs/conventions/package-structure.md#skillmd-optional for frontmatter requirements and installation mechanism.

### Creating a Package with Skill

```bash
mt package new my-package /path/to/module
```

Creates package from template including `SKILL.md.example`. Rename to `SKILL.md` to activate.

## Discovering Packages

```bash
mt module list                    # List modules
mt package list                   # List all packages
mt package list | grep -w git     # Find specific package
```

**Context-efficient workflow**: Use grep to filter rather than loading full list.

## Checking Dependencies

```bash
if ! command -v required-tool >/dev/null; then
  echo "Error: required-tool is needed but not installed" >&2
  exit 1
fi
```

For metool package dependencies:
```bash
if ! command -v other-tool >/dev/null; then
  echo "Error: other-tool from other-package is required" >&2
  echo "Install with: mt package add module/other-package && mt package install other-package" >&2
  exit 1
fi
```

## Troubleshooting

### Conflicts During Installation
When config files conflict, the command prompts to remove existing files and retry.

### Prerequisites
```bash
mt deps              # Check dependencies
mt deps --install    # Auto-install on macOS (requires Homebrew)
```

Requires: GNU coreutils, GNU Stow 2.4.0+

## Documentation Resources

- @docs/conventions/package-structure.md - Complete package conventions
- @docs/conventions/shell-scripting.md - Shell scripting best practices
- @docs/reference/commands/README.md - Command reference
- @docs/templates/service-package/README.md - Service package template
- @docs/guides/GETTING-STARTED.md - Getting started guide
- @docs/guides/package-promotion.md - Package promotion workflow
