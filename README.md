---
alias: metool
---

# MeTool (mt) – Modular Code Organization

![A place for my code](docs/images/20250721011600.png)

MeTool (`mt`) is a modular system for organizing all your code, scripts, and configuration. Each piece of functionality lives in its own package with a clear structure, making it easy to find, edit, share, and evolve your tools over time.

Whether you're capturing a quick shell hack, building a complete application, or managing system services, metool keeps everything organized and accessible—for both humans and AI assistants.

Packages can include a `SKILL.md` file that gives AI assistants like Claude Code the knowledge to help you work with that package's tools and workflows.

## Key Features

- **Instant Access**: Jump to any function's source with `mt cd` or edit with `mt edit`
- **Self-bootstrapping & Modular**: Built as a module itself, making it easy to understand and extend
- **Environment Separation**: Maintain distinct personal, public, and work modules
- **Unix Philosophy**: Leverages symlinks and simple directory structures for maximum flexibility

## Core Commands

- `cd` - Change to MT_ROOT, module, package, or executable
- `deps` - Check metool dependencies (--install to auto-install on macOS)
- `doctor` - Run system health diagnostics
- `edit` - Edit function, executable or file
- `git` - Git repository management commands:
  - `add` - Add repository to .repos.txt manifest
  - `clone` - Clone a git repository to a canonical location
  - `pull` - Pull repositories from repos.txt manifest file
  - `push` - Push local commits for repositories in manifest
  - `repos` - List git repositories
  - `trusted` - Check if repository is trusted
- `module` - Module management commands:
  - `list` - List modules in working set
  - `add` - Add module to working set
  - `remove` - Remove module from working set
  - `edit` - Edit module
  - `update` - Update module(s) from git remote
- `package` - Package management commands:
  - `list` - List packages in working set
  - `add` - Add package to working set
  - `remove` - Remove package from working set
  - `edit` - Edit package
  - `install` - Install package components
  - `uninstall` - Uninstall package (remove symlinks)
  - `new` - Create new package from template
  - `service` - Manage package services
- `reload` - Reload metool
- `update` - Update metool from git

Use `-h` or `--help` for command usage.


## Real-World Value

- **Capture Ideas Fast**: Turn quick hacks into organized, reusable packages
- **Share Selectively**: Keep private packages private, share what's useful
- **Stay Organized**: Never lose track of where useful code lives
- **Works at Any Scale**: From shell functions to complete applications with systemd/launchd services

MeTool brings structure to code while keeping everything accessible and hackable.

## Prerequisites

Metool requires the following tools:

- **GNU coreutils** (for `realpath`)
  - macOS: `brew install coreutils`
  - Ubuntu/Debian: Usually pre-installed
- **GNU Stow 2.4.0+** (for `mt install`)
  - macOS: `brew install stow`
  - Ubuntu/Debian: `apt install stow` (ensure version 2.4.0 or later)
  - Required: Version 2.4.0 or later for proper `dot-` directory support
- **bash-completion** (optional, for alias completion support)
  - macOS: `brew install bash-completion@2`
  - Ubuntu/Debian: `apt install bash-completion`
- **GNU ln** (optional, for relative symlinks)
  - macOS: Included with coreutils
  - Ubuntu/Debian: Pre-installed
- **bats-core** (optional, for running tests)
  - macOS: `brew install bats-core`
  - Ubuntu/Debian: `npm install -g bats` or `apt install bats`

### Checking Dependencies

Use `mt deps` to check if all dependencies are installed:

```shell
# Check dependencies
mt deps

# On macOS with Homebrew, offer to install missing dependencies
mt deps --install
```

Note: `mt install` automatically checks for required dependencies before installing metool.

## Quickstart

### Option 1: One-line installer (Recommended)

```shell
curl -sSL https://raw.githubusercontent.com/mbailey/metool/master/install.sh | bash
```

This will:
- Bootstrap metool using metool itself
- Clone metool to its canonical location (`~/Code/github.com/mbailey/metool` by default)
- Install required dependencies (with your permission)
- Configure your shell (.bashrc or .zshrc)
- Provide next steps

### Option 2: Manual installation

1. Clone and install MeTool:

   ```shell
   git clone https://github.com/mbailey/metool.git
   cd metool
   ./install.sh
   ```

2. Reload your shell:

   ```shell
   source ~/.bashrc  # or ~/.zshrc for zsh users
   ```

3. Verify installation:

   ```shell
   mt --help        # if using bash
   mtbin --help     # works in any shell
   ```

### Install additional packages

```shell
mt clone https://github.com/mbailey/metool-packages.git
mt install metool-packages/*
```

### For zsh users

If you use zsh (default on modern macOS), use the `mtbin` command instead of `mt`:

```shell
mtbin install package-name
mtbin deps --install  # Check and install dependencies
```

## Metool modules

A Metool Module is a collection of Metool Packages.

A typical metool module with packages might look like this:

```shell
~/mt-public/                    # A metool module directory
├── neovim/                     # A metool package
│   ├── bin/                    # (Optional) Executable scripts
│   │   ├── nvim-config-check
│   │   └── nvim-update-plugins
│   ├── config/                 # (Optional) Configuration files
│   │   └── dot-config/         # Maps to ~/.config/
│   │       └── nvim/           # Maps to ~/.config/nvim/
│   │           ├── init.lua
│   │           └── lua/
│   ├── docs/                   # (Optional) Documentation
│   │   └── keybindings.md
│   ├── lib/                    # (Optional) Library files used by bin scripts
│   │   └── nvim-helpers.sh
│   ├── README.md               # Package documentation
│   └── shell/                  # (Optional) Files to be sourced
│       ├── aliases             # Shell aliases
│       ├── env                 # Environment variables
│       └── functions           # Shell functions
└── tmux/                       # Another metool package
    ├── bin/
    ├── config/
    └── README.md
```

When you run `mt install ~/public/neovim`, metool will:

1. Create symlinks from the package's bin/ directory to ~/.metool/bin/
2. Create symlinks from config/ to their respective locations (e.g., dot-config/ to ~/.config/)
3. Create symlinks from shell/ to ~/.metool/shell/

A metool module can contain multiple packages, and you can selectively install packages from different modules.

## Using Metool from Scripts

Since `mt` is implemented as a shell function (to enable environment modifications), it cannot be called directly from scripts. For script usage, metool provides the `mtbin` wrapper:

```bash
#!/bin/bash
# Example: Installing packages from a script

# Use mtbin instead of mt for script usage
mtbin install dev/git-tools
mtbin install personal/shell-utils

# All mt commands work through mtbin
mtbin list
mtbin sync dev
```

The `mtbin` script is installed in metool's `bin/` directory and sources the metool function before executing commands.
