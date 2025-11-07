# Metool Package Development Guide

## Prerequisites

This module depends on the metool repository. Run `mt git sync` to clone or update dependencies listed in `.repos.txt`.

## About This Module

This is a metool module for development packages. Packages here focus on:
- Development tools configuration
- Programming language support
- Editor configurations
- Build tools

When developing packages, consider if they belong here or in other modules like:
- `metool-packages-work/` - For work related packages
- `metool-packages/` - For general-purpose tools to share publicly

## Metool Package Structure

When creating packages in this module, follow the standard metool package structure:

```
package-name/
├── README.md        # Package documentation (required)
├── bin/            # Executable scripts (symlinked to ~/.metool/bin)
├── shell/          # Shell functions, aliases, completions
├── config/         # Config files (use dot- prefix for dotfiles)
├── lib/            # Library functions (sourced, not executed)
├── libexec/        # Helper scripts (not in PATH)
└── docs/           # Additional documentation
```

See `metool/docs/conventions/package-structure.md` for full details.

## Creating a New Package

1. Create package directory: `mkdir -p package-name/{bin,shell,config}`
2. Add README.md with installation and usage instructions
3. For dotfiles in config/, use `dot-` prefix (e.g., `dot-muttrc` → `~/.muttrc`)
4. Make scripts executable: `chmod +x bin/*`
5. Test with: `mt install package-name`

## Metool Conventions

- **Package names**: lowercase with hyphens (e.g., `git-tools`, `mutt-config`)
- **Script names**: descriptive with package prefix if needed (e.g., `mutt-install`)
- **No package.json needed** - metool uses directory structure
- **README.md is the primary package metadata**

## Package README Template

Every package must have a README.md:

```markdown
# Package Name

Brief description of what this package provides

## Installation

\```bash
mt install dev/package-name
\```

## Components

- `bin/tool-name` - Main tool for doing X
- `shell/functions` - Helper functions for Y
- `config/dot-toolrc` - Configuration file

## Usage

[Usage examples]

## Requirements

- bash 4.0+
- other dependencies
```

## Quick Reference

### Shell Components
- `shell/functions` - Shell functions available after sourcing
- `shell/aliases` - Command aliases  
- `shell/completions/` - Bash tab completion
- `shell/environment` - Environment variable exports
- `shell/path` - PATH modifications

### Config Files
GNU Stow converts `dot-` prefix when symlinking:
- `config/dot-toolrc` → `~/.toolrc`
- `config/dot-config/tool/` → `~/.config/tool/`

### Checking Dependencies
```bash
if ! command -v required-tool >/dev/null; then
  echo "Error: required-tool is needed but not installed" >&2
  exit 1
fi
```

## Python Package Conventions

When creating Python packages, use **uv** as the package manager:
- Use `uv run` for script execution with dependency management
- Use inline script metadata (PEP 723) for declaring dependencies
- Scripts in `bin/` should have no `.py` extension

Example inline dependencies:
```python
#!/usr/bin/env python
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests", "click"]
# ///
```

## External Repository Management

- External repos defined in `.repos.txt` using format: `_:org/repo`
- Run `mt git sync` to clone/update external dependencies
- Version pinning supported via `@tag` or `@commit` syntax

## See Also

- Main metool documentation: `metool/README.md`
- Package structure conventions: `metool/docs/conventions/package-structure.md`
- Metool AI guide: `metool/AI.md`
