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
- Reviewing package structure and conventions
- Working with metool commands (install, cd, edit, etc.)
- Setting up configuration files or dotfiles via metool
- Managing shell functions, aliases, or executables
- Creating or updating Claude Code skills for metool packages
- Adding SKILL.md to existing packages

## Core Concepts

### Package Structure

Every metool package follows this standard structure:

```
package-name/
├── README.md        # Package documentation (REQUIRED)
├── SKILL.md         # Claude Code skill (optional, enables AI assistance)
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
mt package add module/package-name
mt package install package-name
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

### mt package add
Add a package from a module to your working set:
```bash
mt package add module/package    # Add package from module to working set
mt package add dev/dependabot    # Example: add dependabot from dev module
```

### mt package install
Install a package by symlinking its components:
```bash
mt package install package-name  # Install package (must be in working set)
mt package install dependabot    # Example: install dependabot package
```

**Complete Installation Workflow:**
```bash
# Step 1: Add package to working set
mt package add dev/dependabot

# Step 2: Install package (create symlinks)
mt package install dependabot
```

### mt install (deprecated)
Legacy command for installing packages:
```bash
mt install package-name          # Install from current directory
mt install path/to/package       # Install specific package
```

**Note:** Use `mt package add` + `mt package install` workflow instead.

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

## Discovering Packages and Modules

### Listing Modules

To see which modules are in the working set:

```bash
mt module list
```

Output shows module name and path:
```
    MODULE                         PATH
--- ------                         ----
✓  dev                         /Users/admin/Code/github.com/mbailey/metool-packages-dev
✓  pub                         /Users/admin/Code/github.com/mbailey/metool-packages
```

### Listing Packages

To see which packages are in the working set:

```bash
mt package list
```

Output shows package name and full path where the symlink points:
```
    PACKAGE                        PATH
--- -------                        ----
✓  git                        /Users/admin/Code/github.com/mbailey/metool-packages-dev/git
✓  agents                     /Users/admin/Code/github.com/mbailey/agents
```

### Finding Specific Packages

To conserve context when searching for a specific package, pipe through grep:

```bash
# Find packages matching 'git' (use word boundary to avoid matching 'github')
mt package list | grep -w git

# Find packages containing 'docker'
mt package list | grep docker
```

**Context-efficient workflow:**
1. Run `mt package list | grep <search-term>` to find the package
2. Note the package name and path from the output
3. Use the path directly instead of re-listing all packages

This approach saves context by showing only relevant matches instead of loading all 200+ packages into the conversation.

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
  echo "Install with: mt package add module/other-package && mt package install other-package" >&2
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

## Claude Code Skills

Skills extend Claude's capabilities by providing specialized knowledge, workflows, and tools. Metool packages can include a `SKILL.md` file to enable AI assistance for the package's domain.

### What Skills Provide

1. **Specialized workflows** - Multi-step procedures for specific domains
2. **Tool integrations** - Instructions for working with specific file formats or APIs
3. **Domain expertise** - Package-specific knowledge, schemas, conventions
4. **Bundled resources** - Scripts, docs, and assets accessible to Claude

### Human-AI Collaborative Infrastructure

Metool packages with skills create infrastructure that serves both humans and AI:

**For Humans:**
- Scripts in `bin/` provide CLI tools available in PATH
- Shell functions and aliases in `shell/` enhance interactive workflows
- Configuration in `config/` manages dotfiles and settings
- `README.md` documents the package for human users

**For AI (Claude):**
- `SKILL.md` provides procedural knowledge and workflow guidance
- References to `bin/` scripts tell Claude what tools are available
- Documentation in `docs/` enables progressive disclosure
- Understanding of `shell/` functions helps Claude guide interactive usage

### SKILL.md Structure

Every skill requires a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: package-name
description: Brief explanation of what the skill does and when to use it. This skill should be used when [specific scenarios].
---

# Package Name

## Overview

[1-2 sentences explaining what this skill enables]

## When to Use

[Specific triggers and use cases]

## Workflows

[Step-by-step procedures, tool references, examples]

## Resources

[References to bin/ scripts, docs/ files, and other package components]
```

**Frontmatter Requirements:**
- `name`: Must be hyphen-case (lowercase letters, digits, hyphens only)
- `description`: Clear explanation of when Claude should use this skill. Use third-person ("This skill should be used when..." not "Use this skill when...")

### Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata** (~100 words) - Always in context (name + description)
2. **SKILL.md body** (<5k words) - Loaded when skill triggers
3. **Package resources** (unlimited) - Loaded as needed by Claude

Scripts in `bin/` can be executed without loading into context, making them token-efficient.

### Adding a Skill to an Existing Package

When adding a skill to an existing metool package:

1. **Create only the SKILL.md file** - Do not overwrite existing README.md or other files
2. **Reference existing tools** - Review what scripts, functions, and docs already exist
3. **Adapt to existing structure** - The SKILL.md should work with the package's current organization

Example: Adding a skill to a `git-tools` package that already has `bin/git-branch-clean`:

```markdown
---
name: git-tools
description: Git workflow utilities for branch management and repository maintenance. This skill should be used when cleaning up git branches, managing worktrees, or automating git workflows.
---

# Git Tools

## Overview

Provides utilities for git branch management and repository maintenance.

## Available Tools

- `git-branch-clean` - Remove merged local branches
- `git-worktree-list` - List all worktrees with status

## Workflows

### Cleaning Up Branches

To clean up merged branches, run:
\`\`\`bash
git-branch-clean
\`\`\`
```

### Creating a New Package with Skill

To create a new metool package with skill support:

```bash
mt package new my-package /path/to/module
```

This creates a package from the template including `SKILL.md.example`:
```
my-package/
├── README.md           # Human documentation template
├── SKILL.md.example    # Claude skill template (rename to SKILL.md to activate)
├── bin/                # Executable scripts directory
├── shell/              # Shell functions directory
├── config/             # Configuration files
└── lib/                # Library functions directory
```

To enable the skill, rename `SKILL.md.example` to `SKILL.md` and complete the TODOs.

### Skill Commands

Metool provides commands for skill management:

```bash
# Create a new package (includes SKILL.md.example template)
mt package new <package-name> [directory]

# Validate package structure and SKILL.md
mt package validate <package-name|path>
```

### Documentation Strategy

- **README.md** - Human-facing: installation, usage examples, requirements
- **SKILL.md** - AI-facing: procedural knowledge, workflows, tool references
- **docs/** - Shared reference: detailed schemas, APIs, conventions

Avoid duplication between README.md and SKILL.md. Each should serve its audience.

### Writing Effective Skills

**Writing Style:** Use imperative/infinitive form (verb-first instructions), not second person. Write "To accomplish X, do Y" rather than "You should do X".

**Content Guidelines:**
- Focus on procedural knowledge that Claude cannot infer
- Reference package tools by their command names (they're in PATH after install)
- Point to docs/ files for detailed reference material
- Include concrete examples with realistic scenarios
- Keep SKILL.md under 5k words; move details to docs/

### Skill Installation

When a package with `SKILL.md` is installed via `mt package install`, metool automatically creates symlinks to make the skill available to Claude Code:

1. Package directory → `~/.metool/skills/<package-name>`
2. `~/.metool/skills/<package-name>` → `~/.claude/skills/<package-name>`

Claude Code discovers skills by scanning `~/.claude/skills/` for `SKILL.md` files.

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
- `docs/reference/commands/README.md` - Command reference index

### Conventions
- `docs/conventions/README.md` - All coding and documentation conventions
- `docs/conventions/documentation/README.md` - Documentation standards and structure
- `docs/conventions/shell-scripting.md` - Shell scripting best practices

### Guides
- `docs/guides/repository-management.md` - Managing repositories with metool

### Templates
- `docs/templates/service-package/README.md` - Service package template

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

# 6. Add package to working set (if in a module)
# Assuming copyparty is in a module, e.g., services module
mt package add services/copyparty

# 7. Install the package
mt package install copyparty

# 8. Run installation script
copyparty-install
```

This example demonstrates all key concepts: structure, dotfile naming, service management, and installation workflow.
