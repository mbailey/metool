# Metool External Commands Analysis

## Executive Summary

After analyzing the metool codebase, I've identified all external commands used and evaluated the need for `command` prefixing. The project already handles some compatibility issues (like GNU ln) but could benefit from a more systematic approach.

## External Commands Used

### Core System Commands
- **File Operations**: `find`, `ls`, `rm`, `mkdir`, `touch`, `ln`, `readlink`
- **Text Processing**: `grep`, `sed`, `cut`, `sort`, `column`, `cat`, `echo`, `printf`
- **Path Operations**: `realpath`, `dirname`, `basename`, `pwd`, `cd`
- **Process/Shell**: `command`, `type`, `which`, `source`, `xargs`
- **Version Control**: `git`
- **Package Management**: `stow`, `brew`

## Commands Most Likely to be Aliased

1. **`find`** → `fd` (already addressed in our patch)
2. **`grep`** → `rg` (ripgrep) or `grep --color=auto`
3. **`ls`** → `ls -la` or `exa`/`eza`
4. **`cat`** → `bat`
5. **`sed`** → `gsed` (on macOS)
6. **`rm`** → `rm -i` (interactive mode)

## Current Compatibility Handling

Metool already handles some compatibility issues:

1. **GNU ln detection** (`lib/functions.sh`):
   ```bash
   # Detects if ln supports -r, falls back to gln on macOS
   _mt_ensure_ln_command()
   ```

2. **Required command checks**:
   - Checks for `realpath` with macOS installation hint
   - Checks for `stow` before use

## Recommendations

### 1. Immediate Actions (Safe to implement)

Prefix these commands with `command` as they're commonly aliased and won't break functionality:
- ✅ `find` → `command find` (already done)
- `grep` → `command grep`
- `sort` → `command sort`
- `cat` → `command cat`
- `rm` → `command rm`
- `mkdir` → `command mkdir`
- `touch` → `command touch`

### 2. Commands to Leave As-Is

These should NOT be prefixed with `command`:
- `cd` - Metool has its own `_mt_cd` function
- `source` - Shell builtin, can't be aliased
- `echo`/`printf` - Builtins, rarely problematic
- Internal metool functions (anything starting with `_mt_`)

### 3. Commands Requiring Special Handling

- **`realpath`**: Already checked at startup
- **`stow`**: Already checked before use
- **`git`**: Leave as-is (users expect their git aliases to work)

### 4. GNU vs BSD Compatibility

For better macOS compatibility, consider:
- Detecting GNU coreutils at startup
- Using feature detection rather than OS detection
- Providing clear error messages for missing GNU tools

## Proposed Implementation Strategy

1. **Phase 1**: Add `command` prefix to commonly aliased commands (grep, sort, cat, rm, mkdir, touch)
2. **Phase 2**: Add startup check for GNU coreutils on macOS
3. **Phase 3**: Consider adding a `--compat-check` flag to verify all dependencies

## Code Patterns to Use

```bash
# Safe pattern for external commands
command grep -E "pattern" file

# Already good - checking command existence
command -v realpath >/dev/null 2>&1

# Keep as-is - internal functions
_mt_cd "$1"
```

## Conclusion

The current patch addressing `find` is a good start. For consistency and robustness, we should apply the same approach to other commonly aliased commands, while being careful not to break internal metool functionality.