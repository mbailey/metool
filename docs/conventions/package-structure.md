# Package Structure Conventions

## Overview

Metool packages are organized collections of related functionality. Each package follows a standard structure for consistency and discoverability.

## Directory Layout

```
module-name/
└── package-name/
    ├── README.md        # Package documentation (required)
    ├── SKILL.md         # Claude Code skill (optional)
    ├── bin/            # Executable scripts
    ├── shell/          # Shell functions and aliases
    ├── config/         # Configuration files
    ├── lib/            # Library functions (sourced, not executed)
    ├── libexec/        # Helper scripts (not in PATH)
    └── docs/           # Additional documentation
```

## Component Directories

### bin/
Executable scripts that will be symlinked to `~/.metool/bin`:

```bash
package-name/
└── bin/
    ├── tool-name       # Main executable
    └── tool-helper     # Related executable
```

Requirements:
- Must be executable (`chmod +x`)
- Should have a shebang line
- Names should be descriptive and unique

### shell/
Shell functions, aliases, environment variables, and completions:

```bash
package-name/
└── shell/
    ├── functions      # Shell functions
    ├── aliases        # Shell aliases
    ├── completions/   # Bash completions
    ├── environment    # Environment variable exports
    └── path           # PATH additions
```

These files are sourced when metool loads.

- **functions** - Shell functions available after sourcing
- **aliases** - Command aliases
- **completions** - Bash tab completion definitions
- **environment** - Environment variable exports (e.g., `export TOOL_HOME="/path"`)
- **path** - PATH modifications (e.g., `export PATH="$PATH:/new/path"`)

### config/
Configuration files to be symlinked to user's home directory:

```bash
package-name/
└── config/
    ├── dot-toolrc     # Becomes ~/.toolrc
    ├── dot-gitconfig  # Becomes ~/.gitconfig
    └── dot-config/    # Becomes ~/.config/
        └── tool/
            └── settings.yml
```

GNU Stow converts `dot-` prefix to `.` when creating symlinks:
- `config/dot-toolrc` → `~/.toolrc`
- `config/dot-bashrc` → `~/.bashrc`
- `config/dot-config/` → `~/.config/`

This convention avoids hidden files in the repository while creating proper dotfiles in the home directory.

### lib/
Library functions used by the package:

```bash
package-name/
└── lib/
    ├── common.sh      # Shared functions
    └── helpers.sh     # Helper functions
```

These are NOT symlinked but can be sourced by scripts.

### libexec/
Helper scripts not exposed in PATH:

```bash
package-name/
└── libexec/
    ├── tool-backend   # Internal helper
    └── tool-worker    # Background worker
```

### SKILL.md (Optional)

Claude Code skill file that makes the package available as a skill in Claude Code:

```markdown
---
name: package-name
description: Brief description of when to use this skill
---

# Package Name Skill

This skill provides...

## When to Use

Use this skill when...

## Available Tools

- `tool-name` - Description of what the tool does
```

When a package contains a `SKILL.md` file, `mt package install` automatically creates symlinks:

1. **Stage 1**: Creates symlink from `~/.metool/skills/{package}` to the package directory
2. **Stage 2**: Creates symlink from `~/.claude/skills/{package}` to `~/.metool/skills/{package}`

This two-stage symlink pattern allows Claude Code to discover the skill while keeping the package as the single source of truth. Claude Code can access all package resources (SKILL.md, docs/, bin/, etc.) through the symlink.

Requirements:
- Must be named `SKILL.md` (all caps)
- Must include YAML frontmatter with `name` and `description`
- Should follow Claude Code skill conventions

To skip skill installation:
```bash
mt package install --no-skill package-name
```

## Package README

Every package must have a README.md:

```markdown
# Package Name

Brief description of what this package provides

## Installation

```bash
mt install module/package
```

## Components

- `bin/tool-name` - Main tool for doing X
- `shell/functions` - Helper functions for Y
- `config/.toolrc` - Configuration file

## Usage

### Command Line

```bash
tool-name [options] <args>
```

### Functions

```bash
# After sourcing
package_function arg1 arg2
```

## Configuration

Configuration file location: `~/.toolrc`

Example configuration:
```ini
[section]
key = value
```

## Requirements

- bash 4.0+
- git (for certain features)

## See Also

- [Other Package](../other-package/README.md) - Related functionality
```

## Service Monitoring Conventions

For packages that install systemd services, provide monitoring commands:

```bash
# In shell/aliases
alias package-logs='journalctl --user -u package-service -f'
alias package-status='systemctl --user status package-service'
alias package-start='systemctl --user start package-service'
alias package-stop='systemctl --user stop package-service'
alias package-restart='systemctl --user restart package-service'
```

This pattern provides consistent service management across all packages.

## Naming Conventions

### Package Names
- Use lowercase with hyphens
- Be descriptive but concise
- Avoid generic names

Good examples:
- `git-tools`
- `docker-helpers`
- `aws-scripts`

Bad examples:
- `utils` (too generic)
- `MyTools` (wrong case)
- `misc` (not descriptive)

### Script Names
- Use lowercase with hyphens
- Include package prefix if needed for clarity
- Make purpose obvious

Examples:
- `git-branch-clean`
- `docker-cleanup`
- `aws-ec2-list`

## Module Organization

Modules group related packages:

```
public/              # Shared with everyone
├── git-tools/
├── docker-helpers/
└── shell-utils/

work/               # Work-specific tools  
├── deploy-scripts/
├── monitoring/
└── automation/

personal/           # Personal tools
├── backup-tools/
├── note-taking/
└── productivity/
```

## Best Practices

1. **One Purpose** - Each package should have a clear, focused purpose
2. **Self-Contained** - Packages should work independently
3. **Well-Documented** - Include README and inline documentation
4. **Tested** - Include tests for complex functionality
5. **Versioned** - Use git tags for package versions

## Creating a New Package

1. Choose appropriate module
2. Create package directory structure
3. Add README.md with documentation
4. Implement functionality in appropriate directories
5. Test the package
6. Install with `mt install`

Example:

```bash
# Create structure
mkdir -p work/deploy-tools/{bin,shell,config,lib}

# Create README
cat > work/deploy-tools/README.md << 'EOF'
# Deploy Tools

Tools for deploying applications
EOF

# Add executable
cat > work/deploy-tools/bin/deploy << 'EOF'
#!/usr/bin/env bash
# Deploy script
EOF
chmod +x work/deploy-tools/bin/deploy

# Install
mt install work/deploy-tools
```

## Package Dependencies

If your package depends on other packages or external tools:

1. Document in README.md under Requirements
2. Check for dependencies in scripts:

```bash
# Check for required command
if ! command -v docker >/dev/null; then
  echo "Error: docker is required but not installed" >&2
  exit 1
fi

# Check for required metool package
if ! command -v other-tool >/dev/null; then
  echo "Error: other-tool from other-package is required" >&2
  echo "Install with: mt install module/other-package" >&2
  exit 1
fi
```
