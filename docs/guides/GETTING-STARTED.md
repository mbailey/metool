# Getting Started with Metool

This guide walks you through installing metool and using the new working set directories to manage your packages.

## Prerequisites

- bash 4.0+
- git
- GNU Stow 2.4.0+

## Installation

### 1. Clone the metool repository

```bash
git clone https://github.com/mbailey/metool.git ~/.metool-src
cd ~/.metool-src
```

### 2. Install metool itself

```bash
# Install metool using stow
stow --dir=. --target="$HOME/.metool" metool

# Add to your shell configuration
echo 'source ~/.metool/shell/mt' >> ~/.bashrc
source ~/.bashrc
```

Verify installation:

```bash
mt --help
```

## Using Working Sets

Metool now uses "working sets" to manage which modules and packages you want to work with. Think of working sets as your active selection of tools.

### Working Set Directories

- `~/.metool/modules/` - Symlinks to module repositories you're using
- `~/.metool/packages/` - Symlinks to packages you want available

## Basic Workflow

### 1. Add a Module to Your Working Set

First, add a module repository that contains packages:

```bash
# Add the public metool-packages module
mt module add mbailey/metool-packages
```

This will:
- Clone the repository (if needed) to `~/Code/github.com/mbailey/metool-packages`
- Create a symlink in `~/.metool/modules/metool-packages`

List your modules:

```bash
mt module list
```

### 2. Browse Available Packages

List packages in a module by checking its directory:

```bash
ls ~/.metool/modules/metool-packages/
```

### 3. Add a Package to Your Working Set

Add a specific package from a module:

```bash
# Format: mt package add <module>/<package>
mt package add metool-packages/git-tools
```

This creates a symlink in `~/.metool/packages/git-tools`.

List your packages:

```bash
mt package list
```

You'll see:
- `○` - Package in working set but not installed
- `●` - Package installed (using stow)
- `✗` - Broken symlink

### 4. Install a Package

Install the package to activate its components:

```bash
mt package install git-tools
```

This uses GNU Stow to symlink:
- `bin/` files to `~/.metool/bin/`
- `config/` files to `~/` (with dot- prefix converted to .)
- `shell/` files to `~/.metool/shell/`

Reload your shell to pick up new functions and aliases:

```bash
source ~/.metool/shell/mt
```

### 5. Verify Installation

Check that the package is now marked as installed:

```bash
mt package list
# Should show ● next to git-tools
```

## Selective Installation

You can install only specific components:

```bash
# Install only shell functions and aliases (skip bin and config)
mt package install vim-config --no-bin --no-config

# Install only binaries (skip config and shell)
mt package install docker-tools --no-config --no-shell
```

## Managing Services

If a package includes systemd (Linux) or launchd (macOS) services:

```bash
# List services in a package
mt package service list prometheus

# Start a service
mt package service start prometheus

# Check service status
mt package service status prometheus

# View logs
mt package service logs prometheus -f

# Enable service to start at boot/login
mt package service enable prometheus
```

## Uninstalling

### Remove Symlinks (Uninstall)

Remove stow symlinks but keep package in working set:

```bash
mt package uninstall git-tools
```

### Remove from Working Set

Remove package from your working set:

```bash
mt package remove git-tools
```

This removes the symlink from `~/.metool/packages/` but preserves the module repository.

### Remove Module

Remove a module from your working set:

```bash
mt module remove metool-packages
```

This removes the symlink from `~/.metool/modules/` but preserves the repository in `~/Code/github.com/`.

## Example: Fresh Start Workflow

Here's a complete example of setting up metool from scratch:

```bash
# 1. Install metool
git clone https://github.com/mbailey/metool.git ~/.metool-src
cd ~/.metool-src
stow --dir=. --target="$HOME/.metool" metool
echo 'source ~/.metool/shell/mt' >> ~/.bashrc
source ~/.bashrc

# 2. Add a module
mt module add mbailey/metool-packages

# 3. Add packages you want
mt package add metool-packages/git-tools
mt package add metool-packages/docker-helpers

# 4. Install the packages
mt package install git-tools
mt package install docker-helpers

# 5. Reload shell
source ~/.metool/shell/mt

# 6. Verify
mt module list
mt package list
```

## Testing the New Features

To test the MT-11 changes without affecting your existing setup:

```bash
# 1. Rename your existing .metool directory
mv ~/.metool ~/.metool.backup

# 2. Use the worktree version
cd /path/to/worktree
source shell/mt

# 3. Follow the fresh start workflow above

# 4. When done testing, restore your original
rm -rf ~/.metool
mv ~/.metool.backup ~/.metool
source ~/.metool/shell/mt
```

## Getting Help

- `mt --help` - General help
- `mt module --help` - Module commands
- `mt package --help` - Package commands
- `mt package service --help` - Service commands

## Next Steps

- Explore available packages: `ls ~/.metool/modules/*/`
- Create your own package: `mt package new my-package`
- Edit a package: `mt package edit git-tools`
- Check the documentation in `docs/` for advanced features
