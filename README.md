---
alias: metool
---

# MeTool (mt) – A Propagation tray for Ideas

![A place for my code](docs/images/20250721011600.png)

MeTool (`mt`) is a lightweight, modular system designed to capture, organize,
and evolve my shell environment. Like a gardener's propagation tray for
seedlings, it provides the perfect environment where scripts, functions, and
tools can take root and grow before being transplanted into standalone
projects.

## Key Features

- **Instant Access**: Jump to any function's source with `mt cd` or edit with `mt edit`
- **Self-bootstrapping & Modular**: Built as a module itself, making it easy to understand and extend
- **Environment Separation**: Maintain distinct personal, public, and work modules
- **Unix Philosophy**: Leverages symlinks and simple directory structures for maximum flexibility

## Core Commands

- `cd` - Change to mt root or specified target
- `clone` - Clone a git repository to a canonical location (or show status if already cloned)
- `components` - List all package components (bin, shell, config, etc.)
- `disable` - Disable systemd service(s) while preserving service files
- `deps` - Check metool dependencies (--install to auto-install on macOS)
- `edit` - Edit function, executable or file
- `enable` - Enable systemd service(s) from a package
- `install` - Symlink package directories: bin, config, shell
- `modules` - List all metool modules (collections of packages)
- `packages` - List all metool packages with their parent modules
- `reload` - Reload metool
- `sync` - Sync repositories from repos.txt manifest file
- `update` - Update metool from git

Use `--help` for command usage.

## Real-World Value

- **Capture Ideas Fast**: Turn quick shell hacks into organized, reusable tools
- **Share Selectively**: Keep private scripts private, share what's useful
- **Evolve Naturally**: Start simple, refactor safely, extract when ready
- **Stay Organized**: Never lose track of where that useful function lives

MeTool brings structure to shell creativity while keeping everything accessible
and hackable.

## Prerequisites

Metool requires the following tools:

- **GNU coreutils** (for `realpath`)
  - macOS: `brew install coreutils`
  - Ubuntu/Debian: Usually pre-installed
- **GNU Stow** (for `mt install`)
  - macOS: `brew install stow`
  - Ubuntu/Debian: `apt install stow`
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

Metool itself is a Metool Package you install as you would any other Metool Package:

1. Install MeTool core:

   ```shell
   git clone https://github.com/mbailey/metool.git
   source metool/shell/mt
   mt install  # Installs from MT_ROOT and offers to update .bashrc
   ```

2. Start using MeTool:

   ```shell
   # If you accepted the .bashrc update, restart your shell or:
   source ~/.bashrc

   # Try some commands
   mt --help
   ```

3. Install additional modules:

   ```shell
   mt clone https://github.com/mbailey/metool-packages.git
   mt install metool-packages/*
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
