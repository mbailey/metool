# Installing Metool

## Quick Install (Recommended)

Clone the repository and run the installer:

```bash
git clone https://github.com/mbailey/metool.git
cd metool
./install.sh
```

The installer will:
- Check for required dependencies (realpath, stow, modern bash)
- Install missing dependencies via Homebrew (macOS) or apt/yum (Linux)
- Configure metool in your shell (~/.bashrc or ~/.zshrc)
- Provide instructions for your specific setup

## For Zsh Users

If you use zsh (default on modern macOS), you have two options:

### Option 1: Use mtbin (Recommended)
After installation, use `mtbin` instead of `mt`:
```bash
mtbin install package-name
mtbin modules
mtbin --help
```

### Option 2: Switch to Bash
```bash
exec bash
mt install package-name
```

## Manual Installation

If you prefer manual installation:

### 1. Install Dependencies

**macOS:**
```bash
brew install coreutils stow bash bash-completion@2
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install coreutils stow bash-completion
```

### 2. Install Metool

```bash
# Use modern bash
/opt/homebrew/bin/bash  # macOS
# or
/usr/bin/bash           # Linux

# Source and install
source shell/mt
mt install
```

### 3. Configure Shell

Add to your shell config file:

**For ~/.bashrc:**
```bash
if [[ -f "$HOME/.metool/shell/metool/mt" ]]; then
    source "$HOME/.metool/shell/metool/mt"
fi
export PATH="$HOME/.metool/bin:$PATH"
```

**For ~/.zshrc:**
```bash
# Use mtbin command instead of mt function
export PATH="$HOME/.metool/bin:$PATH"
```

## Troubleshooting

### "bad substitution" Error
This means you're using an old version of bash. The installer should handle this automatically, but if not:
- macOS: Use `/opt/homebrew/bin/bash` instead of `/bin/bash`
- Check bash version: `bash --version` (need 4.0+)

### Zsh "command not found: mt"
The `mt` function requires bash. Use `mtbin` instead or switch to bash with `exec bash`.

### Dependencies Not Found
Run `mt deps --install` (or `mtbin deps --install`) to check and install missing dependencies.

## Next Steps

After installation:

1. **Test metool:**
   ```bash
   mt --help    # if using bash
   mtbin --help # if using zsh or other shells
   ```

2. **Install packages:**
   ```bash
   mt clone https://github.com/mbailey/metool-packages.git
   mt install metool-packages/*
   ```

3. **Explore commands:**
   ```bash
   mt modules   # List available modules
   mt packages  # List all packages
   mt cd        # Navigate to metool root
   ```