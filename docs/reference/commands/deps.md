# mt deps

Check metool dependencies and optionally install missing ones.

## Usage

```shell
mt deps [--install]
```

## Description

The `deps` command checks for all required and optional metool dependencies, reporting their status and installation instructions.

When run without arguments, it performs a comprehensive check of:
- Required dependencies (realpath, stow)
- Optional but recommended tools (GNU ln, bash-completion, bats)

## Options

- `--install` - Offer to install missing dependencies (macOS/Homebrew only)

## Examples

Check all dependencies:
```shell
$ mt deps
Checking metool dependencies...

  ✅ realpath: Found at /opt/homebrew/opt/coreutils/libexec/gnubin/realpath
  ✅ stow: Found at /opt/homebrew/bin/stow
  ✅ ln: Found at /opt/homebrew/opt/coreutils/libexec/gnubin/ln (supports -r for relative symlinks)
  ✅ bash-completion: Found at /opt/homebrew/etc/profile.d/bash_completion.sh
  ✅ bats: Found at /opt/homebrew/bin/bats

✅ All required dependencies found!
```

Install missing dependencies on macOS:
```shell
$ mt deps --install
Checking metool dependencies...

  ❌ realpath: Not found
     Install: brew install coreutils (macOS) or apt install coreutils (Linux)
  ❌ stow: Not found
     Install: brew install stow (macOS) or apt install stow (Linux)

❌ Missing required dependencies:
   - realpath (from GNU coreutils)
   - stow

🍺 Homebrew detected. Would you like to install missing dependencies?

The following Homebrew packages will be installed:
  - coreutils
  - stow

Would you like to install these dependencies? [y/N]
```

## Dependencies Checked

### Required Dependencies

- **realpath** - From GNU coreutils, used for canonical path resolution
- **stow** - GNU Stow, used by `mt install` to manage symlinks

### Optional Dependencies

- **GNU ln with -r support** - For creating relative symlinks
- **bash-completion** - For shell completion of aliases
- **bats-core** - For running the test suite

## Notes

- The `--install` flag only works on macOS with Homebrew installed
- On Linux systems, use your package manager directly (apt, yum, etc.)
- `mt install` automatically runs dependency checks before installing metool
- Missing optional dependencies will show warnings but won't prevent metool from functioning

## See Also

- [install](install.md) - Install metool packages (checks dependencies first)
- [Prerequisites](../../../README.md#prerequisites) - Full list of prerequisites