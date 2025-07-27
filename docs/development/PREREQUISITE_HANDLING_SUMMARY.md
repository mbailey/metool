# Metool Prerequisite Handling Summary

## Current Prerequisite Checks

Metool currently performs the following prerequisite checks:

### 1. At Startup (shell/mt)
- **realpath**: Required check with error message and installation hint
  ```bash
  command -v realpath &>/dev/null || {
    echo "Error: 'realpath' is required but not found. Please install 'coreutils'..." >&2
    return 1
  }
  ```

### 2. On `mt install` (lib/stow.sh)
- **stow**: Required check with error message and installation hint
  ```bash
  command -v stow &>/dev/null || {
    echo "Error: 'stow' command is required but not found." >&2
    echo "Please install GNU Stow (e.g. 'apt install stow' or 'brew install stow')" >&2
    return 1
  }
  ```

### 3. For Symlink Creation (lib/functions.sh)
- **GNU ln with -r support**: Automatic detection and fallback to `gln`
  - Tests if `ln` supports `-r` flag
  - Falls back to `gln` if available
  - Shows error only when trying to create relative symlinks without support

### 4. For Alias Completion (shell/mt - updated)
- **bash-completion**: Now checks if loaded before using `_complete_alias`
  ```bash
  if type -t _complete_alias &>/dev/null; then
    complete -F _complete_alias "${!BASH_ALIASES[@]}"
  fi
  ```

## New Prerequisite Command

Added `mt deps` command that provides comprehensive checking:

```bash
$ mt deps
Checking metool dependencies...

  ✅ realpath: Found at /opt/homebrew/opt/coreutils/libexec/gnubin/realpath
  ✅ stow: Found at /opt/homebrew/bin/stow
  ✅ ln: Found at /opt/homebrew/opt/coreutils/libexec/gnubin/ln (supports -r for relative symlinks)
  ✅ bash-completion: Found at /opt/homebrew/etc/profile.d/bash_completion.sh

✅ All required prerequisites found!
```

The command checks for:
- Required tools (realpath, stow)
- Optional but recommended tools (GNU ln, bash-completion)
- Provides installation instructions for missing tools
- Differentiates between required and optional prerequisites

## Installation Automation

Metool does NOT automatically install prerequisites because:
1. Installation requires system privileges (sudo/admin)
2. Package managers vary by platform (brew, apt, yum, etc.)
3. Users may have preferences for installation methods
4. Some organizations have policies about software installation

Instead, metool:
- Provides clear error messages when prerequisites are missing
- Includes platform-specific installation commands in error messages
- Offers the `mt deps` command for comprehensive checking
- Documents prerequisites in the README

## Summary

Metool takes a balanced approach to prerequisites:
- **Fails fast** for critical dependencies (realpath)
- **Fails gracefully** for command-specific dependencies (stow)
- **Falls back automatically** when alternatives exist (ln/gln)
- **Skips optional features** when dependencies are missing (bash-completion)
- **Provides guidance** but doesn't install automatically