# mt install

Symlink package directories to make their components available system-wide.

## Usage

```bash
mt install [package]     # Install a specific package
mt install               # Install current directory as a package
```

## Description

The `install` command uses GNU Stow to create symlinks from package directories to the metool integration directory (`~/.metool`). This makes package components (binaries, shell configs, dotfiles) available for use.

## Components Installed

- **bin/** → `~/.metool/bin/` (executables in PATH)
- **shell/** → `~/.metool/shell/` (sourced on shell startup)
- **config/** → `~/.metool/config/` → `~/` (dotfiles via --dotfiles)

## Examples

```bash
# Install the tmux package
mt install ~/.config/metool/packages/tmux

# Install from within a package directory
cd ~/.config/metool/packages/vim
mt install

# Install with stow options (verbose)
mt install -v ~/.config/metool/packages/git

# Install multiple packages
mt install ~/.config/metool/packages/*
```

## Conflict Resolution

When installing config files that already exist in your home directory:

1. The command will show which files conflict
2. You'll be prompted to remove existing files
3. If you accept, the conflicting file is removed and installation retries
4. Broken symlinks are identified and can be safely removed

## Requirements

- GNU Stow must be installed (`apt install stow` or `brew install stow`)
- Package directory must exist and contain at least one component directory

## Notes

- Uses GNU Stow internally for reliable symlink management
- Automatically creates required target directories
- Invalidates metool's cache after installation
- For metool itself, offers to update .bashrc after successful installation