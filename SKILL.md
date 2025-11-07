---
name: metool
description: Package management system for organizing, installing, and managing shell scripts, dotfiles, and development tools. Use this skill when creating, modifying, reviewing, or installing metool packages, or when working with metool commands and package structure.
---

# Metool Package Management

## Overview

Metool (mt) is a modular system for managing shell environments through packages. It provides a "propagation tray for ideas" - a place where scripts, functions, and tools can be organized, tested, and evolved before becoming standalone projects.

## When to Use This Skill

Use this skill when:
- Creating new metool packages
- Installing or modifying metool packages
- Reviewing package structure and conventions
- Working with metool commands (install, cd, edit, etc.)
- Setting up configuration files or dotfiles via metool
- Managing shell functions, aliases, or executables

## Core Concepts

### Package Structure

Every metool package follows this standard structure:

```
package-name/
├── README.md        # Package documentation (REQUIRED)
├── bin/            # Executable scripts (symlinked to ~/.metool/bin)
├── shell/          # Shell functions, aliases, completions
├── config/         # Config files (use dot- prefix for dotfiles)
├── lib/            # Library functions (sourced, not executed)
├── libexec/        # Helper scripts (not in PATH)
└── docs/           # Additional documentation
```

### Installation Mechanism

Metool uses GNU Stow to create symlinks:
- `bin/` → `~/.metool/bin/` (executables in PATH)
- `shell/` → `~/.metool/shell/` (sourced on shell startup)
- `config/` → `~/.metool/config/` → `~/` (dotfiles via --dotfiles)

### Dotfile Naming Convention

Files in `config/` use `dot-` prefix which gets converted:
- `config/dot-bashrc` → `~/.bashrc`
- `config/dot-gitconfig` → `~/.gitconfig`
- `config/dot-config/tool/` → `~/.config/tool/`

This avoids hidden files in the repository while creating proper dotfiles in home directory.

## Creating a New Package

### Step 1: Create Package Directory Structure

```bash
# Create package directory
mkdir -p package-name/{bin,shell,config,lib}
```

### Step 2: Create README.md

Every package MUST have a README.md. Use this template:

```markdown
# Package Name

Brief description of what this package provides

## Installation

\`\`\`bash
mt install module/package-name
\`\`\`

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

### Step 3: Add Package Components

#### Executables (bin/)
```bash
# Create executable script
cat > package-name/bin/tool-name << 'EOF'
#!/usr/bin/env bash
# Tool description
EOF

chmod +x package-name/bin/tool-name
```

Requirements for bin/ scripts:
- Must be executable (`chmod +x`)
- Should have shebang line
- Names should be descriptive and unique

#### Shell Functions (shell/)
```bash
# Create shell functions
cat > package-name/shell/functions << 'EOF'
# Function description
function_name() {
    # Implementation
}
EOF
```

Shell directory structure:
- `shell/functions` - Shell functions
- `shell/aliases` - Command aliases
- `shell/completions/` - Bash tab completion
- `shell/environment` - Environment variable exports
- `shell/path` - PATH modifications

#### Configuration Files (config/)
```bash
# Create config with dot- prefix
mkdir -p package-name/config
cat > package-name/config/dot-toolrc << 'EOF'
# Configuration
EOF
```

Remember: Use `dot-` prefix for all dotfiles!

### Step 4: Install the Package

```bash
mt install package-name
```

This uses GNU Stow to create symlinks from package directories to `~/.metool/`.

## Package Naming Conventions

### Package Names
- Lowercase with hyphens: `git-tools`, `docker-helpers`
- Be descriptive but concise
- Avoid generic names like `utils` or `misc`

### Script Names
- Lowercase with hyphens
- Include package prefix if needed for clarity
- Make purpose obvious

Examples:
- `git-branch-clean`
- `docker-cleanup`
- `aws-ec2-list`

## Python Package Conventions

When creating Python packages:

1. Use **uv** as the package manager
2. Use inline script metadata (PEP 723) for dependencies
3. Scripts in `bin/` should have no `.py` extension

Example with inline dependencies:
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

## Common Commands

### mt install
Install a package by symlinking its components:
```bash
mt install package-name          # Install from current directory
mt install path/to/package       # Install specific package
mt install -v package-name       # Verbose mode
```

### mt cd
Change to metool root or specific component:
```bash
mt cd                    # Go to metool root
mt cd package-name       # Go to package directory
```

### mt edit
Edit functions, executables, or files:
```bash
mt edit function-name    # Edit a shell function
mt edit command-name     # Edit an executable
```

### mt components
List all package components:
```bash
mt components            # List all components
```

### mt packages
List all metool packages:
```bash
mt packages              # Show all packages with modules
```

### mt reload
Reload metool configuration:
```bash
mt reload                # Reload shell configuration
```

## Checking Dependencies

Always check for required tools in scripts:

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
  echo "Install with: mt install module/other-package" >&2
  exit 1
fi
```

## Service Packages (systemd/launchd)

For packages that install services, provide monitoring aliases in `shell/aliases`:

```bash
# macOS launchd example
alias package-logs='tail -f ~/Library/Logs/package-service.log'
alias package-status='launchctl list | grep package-service'
alias package-start='launchctl load ~/Library/LaunchAgents/com.user.package.plist'
alias package-stop='launchctl unload ~/Library/LaunchAgents/com.user.package.plist'

# Linux systemd example
alias package-logs='journalctl --user -u package-service -f'
alias package-status='systemctl --user status package-service'
alias package-start='systemctl --user start package-service'
alias package-stop='systemctl --user stop package-service'
alias package-restart='systemctl --user restart package-service'
```

## Module Organization

Modules group related packages:

```
metool-packages/         # Public shared packages
metool-packages-dev/     # Development packages
metool-packages-personal/# Personal packages
metool-packages-work/    # Work-specific packages
```

## Best Practices

1. **One Purpose** - Each package should have a clear, focused purpose
2. **Self-Contained** - Packages should work independently
3. **Well-Documented** - Include README and inline documentation
4. **Tested** - Test packages before installing
5. **Dependencies** - Document and check for dependencies

## Troubleshooting

### Conflicts During Installation

When installing config files that already exist:
1. The command shows which files conflict
2. You're prompted to remove existing files
3. If accepted, conflicting file is removed and installation retries
4. Broken symlinks are identified and can be safely removed

### Prerequisites

Metool requires:
- **GNU coreutils** (for `realpath`)
  - macOS: `brew install coreutils`
  - Ubuntu: Usually pre-installed
- **GNU Stow 2.4.0+** (for `mt install`)
  - macOS: `brew install stow`
  - Ubuntu: `apt install stow`

Check dependencies:
```bash
mt deps              # Check dependencies
mt deps --install    # Auto-install on macOS
```

## Documentation Resources

For detailed information, refer to existing metool documentation:

### Core Documentation
- `README.md` - Main metool documentation and quickstart
- `docs/conventions/package-structure.md` - Complete package structure conventions
- `docs/reference/commands/` - Individual command documentation

### Guides
- `docs/guides/repository-management.md` - Managing repositories with metool
- `docs/systemd.md` - Systemd service management

### Conventions
- `docs/conventions/shell-scripting.md` - Shell scripting best practices
- `docs/conventions/documentation.md` - Documentation standards
- `docs/conventions/testing.md` - Testing guidelines

### Templates
- `docs/templates/service-package/` - Service package template

Use the Read tool to load specific documentation files as needed during package development

## Example: Creating a Service Package

Here's a complete example of creating a CopyParty file sharing package:

```bash
# 1. Create structure
mkdir -p copyparty/{bin,config/dot-config/copyparty,lib/launchd}

# 2. Create README
cat > copyparty/README.md << 'EOF'
# CopyParty File Sharing

File sharing service via CopyParty

## Installation
\`\`\`bash
mt install copyparty
\`\`\`

## Components
- `bin/copyparty-install` - Installation script
- `config/.config/copyparty/config.yaml` - Configuration
- `lib/launchd/com.user.copyparty.plist` - Launch agent

## Usage
Service starts automatically on login
EOF

# 3. Create installation script
cat > copyparty/bin/copyparty-install << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Install copyparty via uv
uv tool install copyparty

# Install launchd service
cp lib/launchd/com.user.copyparty.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.copyparty.plist
EOF

chmod +x copyparty/bin/copyparty-install

# 4. Create configuration
cat > copyparty/config/dot-config/copyparty/config.yaml << 'EOF'
port: 3923
directories:
  - path: ~/.cora
    permissions: read,write
EOF

# 5. Create launchd plist
cat > copyparty/lib/launchd/com.user.copyparty.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.copyparty</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/uvx</string>
        <string>copyparty</string>
        <string>--http-only</string>
        <string>-p</string>
        <string>3923</string>
        <string>/Users/admin/.cora</string>
        <string>--read</string>
        <string>--write</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# 6. Install the package
mt install copyparty

# 7. Run installation script
copyparty-install
```

This example demonstrates all key concepts: structure, dotfile naming, service management, and installation workflow.
