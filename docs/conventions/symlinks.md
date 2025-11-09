# Symlink Resolution in Bin Scripts

## Problem

When metool installs a package, scripts in `bin/` are symlinked to `~/.metool/bin/`. If these scripts need to access sibling directories like `libexec/` or `lib/`, relative paths won't work correctly because they'll resolve relative to the symlink location (`~/.metool/bin/`) rather than the actual script location.

## Solution

Use `realpath` to resolve the symlink before calculating relative paths:

```bash
#!/usr/bin/env bash

# Resolve symlinks to find actual script location
SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Now you can reliably access sibling directories
LIBEXEC_DIR="$PACKAGE_DIR/libexec"
LIB_DIR="$PACKAGE_DIR/lib"
```

## Example

Given this package structure:

```
my-package/
├── bin/
│   └── my-command          # Symlinked to ~/.metool/bin/my-command
├── libexec/
│   ├── my-subcommand-1
│   └── my-subcommand-2
└── lib/
    └── common.sh
```

### Without realpath (WRONG):

```bash
#!/usr/bin/env bash
# This will FAIL when script is symlinked!

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBEXEC_DIR="$(dirname "$SCRIPT_DIR")/libexec"

# LIBEXEC_DIR will be ~/.metool/libexec (doesn't exist!)
# Should be ~/skills/my-package/libexec
```

### With realpath (CORRECT):

```bash
#!/usr/bin/env bash
# This works correctly even when symlinked

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
LIBEXEC_DIR="$(dirname "$SCRIPT_DIR")/libexec"

# LIBEXEC_DIR will correctly resolve to ~/skills/my-package/libexec
```

## Why This Matters

When you run `my-command` from anywhere:
1. Shell finds `~/.metool/bin/my-command` (the symlink)
2. Without `realpath`: Script thinks it's in `~/.metool/bin/`
3. With `realpath`: Script knows it's actually in `~/skills/my-package/bin/`

This allows the script to correctly find `libexec/my-subcommand-1` at `~/skills/my-package/libexec/my-subcommand-1`.

## Checking for realpath

`realpath` is provided by GNU coreutils. Always check if it's available:

```bash
#!/usr/bin/env bash

# Check for realpath
if ! command -v realpath &> /dev/null; then
    echo "Error: 'realpath' is required. Install with:" >&2
    echo "  macOS: brew install coreutils" >&2
    echo "  Linux: Usually pre-installed" >&2
    exit 1
fi

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
# ... rest of script
```

## Common Pattern

Here's the standard pattern for bin scripts that use libexec:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve symlinks to find actual script location
command -v realpath &> /dev/null || {
    echo "Error: 'realpath' required. Install coreutils." >&2
    exit 1
}

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
LIBEXEC_DIR="$PACKAGE_DIR/libexec"

# Now you can call libexec scripts
"$LIBEXEC_DIR/subcommand" "$@"
```

## Alternative: Embed Subcommands

If you don't want to deal with libexec and symlink resolution, you can embed all logic in a single bin script:

```bash
#!/usr/bin/env bash
# All-in-one script - no libexec needed

case "${1:-}" in
    subcommand1)
        # Implementation here
        ;;
    subcommand2)
        # Implementation here
        ;;
    *)
        echo "Unknown command"
        ;;
esac
```

This avoids the symlink issue but makes the script longer and harder to maintain.

## Best Practices

1. **Always use realpath** when bin scripts need to access libexec or lib
2. **Check for realpath availability** at the start of the script
3. **Test both ways**: Run script directly AND via symlink
4. **Document dependencies**: Mention coreutils requirement in README

## See Also

- [Shell Scripting Conventions](shell-scripting.md) - General bash conventions
- [Package Structure](package-structure.md) - Overview of package layout
- [Service Package Template](/docs/templates/service-package/) - Example using this pattern
