# Metool Bootstrap Guide

Complete bootstrap for a fresh Mac or Linux workstation.

## Prerequisites

- **git** - Usually pre-installed
- **curl** - Usually pre-installed
- **brew** (macOS) - Install from https://brew.sh if needed

## Quick Bootstrap (Copy/Paste)

```bash
# Clone metool to temp
cd /tmp
git clone https://github.com/mbailey/metool.git
cd metool

# Install dependencies (coreutils, stow, bash 4+)
./bin/mt deps --fix

# Add metool-packages module
MT_ROOT=/tmp/metool ./bin/mt module add mbailey/metool-packages

# Clone all repos listed in metool-packages/.repos.txt
cd ~/.metool/modules/metool-packages
MT_ROOT=/tmp/metool /tmp/metool/bin/mt git pull

# Add all packages from metool-packages to working set
MT_ROOT=/tmp/metool /tmp/metool/bin/mt package add metool-packages/*

# Install metool itself (creates ~/.metool structure)
MT_ROOT=/tmp/metool /tmp/metool/bin/mt package install metool

# Add to shell config (one-time)
echo 'source "$HOME/.metool/shell/init.sh"' >> ~/.zshrc

# Start new shell or source it
source ~/.zshrc
```

## Step-by-Step Explanation

### 1. Clone metool to temp

```bash
cd /tmp
git clone https://github.com/mbailey/metool.git
cd metool
```

We clone to `/tmp` because metool will install itself to the canonical path later.

### 2. Install dependencies

```bash
./bin/mt deps --fix
```

This installs via Homebrew:
- **coreutils** - Provides `realpath` (required)
- **stow** - For symlink management (required)
- **bash 4+** - macOS ships with bash 3.2 (required)
- **bash-completion@2** - For tab completion (optional)

### 3. Add metool-packages module

```bash
MT_ROOT=/tmp/metool ./bin/mt module add mbailey/metool-packages
```

This:
- Clones `metool-packages` to `~/Code/github.com/mbailey/metool-packages`
- Creates symlink `~/.metool/modules/metool-packages`

### 4. Clone repos from manifest

```bash
cd ~/.metool/modules/metool-packages
MT_ROOT=/tmp/metool /tmp/metool/bin/mt git pull
```

This reads `.repos.txt` in metool-packages and clones all listed repositories to their canonical paths.

### 5. Add packages to working set

```bash
MT_ROOT=/tmp/metool /tmp/metool/bin/mt package add metool-packages/*
```

This adds all packages from metool-packages to your working set (`~/.metool/packages/`).

### 6. Install packages

```bash
# Install metool first
MT_ROOT=/tmp/metool /tmp/metool/bin/mt package install metool

# Install other packages you want
mt package install git-tools tmux vim-config  # etc.
```

### 7. Add to shell config

```bash
# For zsh
echo 'source "$HOME/.metool/shell/init.sh"' >> ~/.zshrc

# For bash
echo 'source "$HOME/.metool/shell/init.sh"' >> ~/.bashrc
```

## After Bootstrap

Once metool is installed, you can use `mt` directly:

```bash
# List installed packages
mt package list

# Install more packages
mt package install <package-name>

# Update modules
mt module update --all

# Check system health
mt doctor
```

## Private Packages (Optional)

After setting up SSH keys with keycutter, add your private module:

```bash
mt module add mbailey/metool-packages-dev
cd ~/.metool/modules/metool-packages-dev
mt git pull
mt package add metool-packages-dev/*
mt package install <your-private-packages>
```

## Cleanup

After bootstrap completes, you can remove the temp clone:

```bash
rm -rf /tmp/metool
```
