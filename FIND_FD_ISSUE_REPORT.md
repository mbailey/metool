# Find vs FD Issue Report

## Problem Summary

The metool project is failing with the error:
```
error: invalid value 'ype' for '--type <filetype>'
```

This occurs because the `find` command is aliased to `fd` in `~/.bashrc` (line 82), and `fd` uses different syntax than GNU find.

## Root Cause

1. **Not a Homebrew issue**: Homebrew did NOT replace find with fd. The issue is caused by a manual alias in `~/.bashrc`:
   ```bash
   alias find='fd'
   ```

2. **Current find setup**:
   - GNU find is properly installed at `/opt/homebrew/opt/findutils/libexec/gnubin/find`
   - GNU find is in PATH and would work correctly without the alias
   - The alias intercepts all `find` commands and redirects them to `fd`

## Find Usage in Metool

The project uses `find` in several critical locations:

### 1. `shell/mt` (line 62)
```bash
find -L "${MT_PKG_DIR}/shell" -type f -not -name ".*" -print0 | sort -z
```

### 2. `lib/functions.sh`
- Line 209: `find "${MT_PKG_DIR}/bin" -type l -print0`
- Line 249: `find "${MT_PKG_DIR}/shell" -type l -print0 2>/dev/null`
- Line 294: `find "${MT_PKG_DIR}/${dir}" -type l -print0 2>/dev/null`
- Line 472: `find "${MT_PKG_DIR}/${dir}" -type l -newer "${timestamp_file}" -print -quit`

### 3. Test files and completions also use find

## Solutions

### Solution 1: Use Absolute Path (Recommended)
Modify metool to use the absolute path to GNU find:

```bash
# Define at the top of shell/mt and lib/functions.sh
FIND_CMD="/usr/bin/find"  # macOS system find
# or
FIND_CMD="/opt/homebrew/opt/findutils/libexec/gnubin/find"  # GNU find

# Then use $FIND_CMD instead of find
```

### Solution 2: Use Command Builtin
Bypass aliases using the `command` builtin:

```bash
command find -L "${MT_PKG_DIR}/shell" -type f -not -name ".*" -print0
```

### Solution 3: Unset Function/Alias
Add this at the beginning of metool scripts:

```bash
unalias find 2>/dev/null || true
unset -f find 2>/dev/null || true
```

### Solution 4: Full Path Detection
Add intelligent detection:

```bash
# Detect GNU find
if command -v gfind >/dev/null 2>&1; then
    FIND_CMD="gfind"
elif [[ -x "/opt/homebrew/opt/findutils/libexec/gnubin/find" ]]; then
    FIND_CMD="/opt/homebrew/opt/findutils/libexec/gnubin/find"
elif [[ -x "/usr/bin/find" ]]; then
    FIND_CMD="/usr/bin/find"
else
    FIND_CMD="find"
fi
```

## Recommendation

I recommend **Solution 2** (using `command find`) as it:
1. Works regardless of user aliases
2. Doesn't hardcode paths
3. Is POSIX compliant
4. Requires minimal changes to the codebase

## Immediate Fix

To fix your current issue immediately:
1. Remove or comment out the alias in `~/.bashrc` line 82
2. Or run: `unalias find` in your current shell
3. Then source the mt script again

## Long-term Fix

The metool project should be updated to be resilient against user aliases by using `command find` throughout the codebase.