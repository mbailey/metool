# Technical Specification: MT-51 - Add 'mt which' command

## Overview

Implement `mt which <name>` command to resolve and display the real path of binaries, following symlinks to show actual file locations. This complements `mt cd` and `mt edit` by providing path resolution without navigation or editing.

## Implementation Strategy

### Core Approach
Reuse the search logic from `_mt_cd` but output the resolved path instead of changing directory. The command will:
1. Search in the same order as `mt cd`: modules → packages → functions → executables
2. Use `realpath` to resolve all symlinks to the actual file location
3. Output only the path (script-friendly, no decoration)
4. Return appropriate exit codes (0=success, 1=not found)

### Design Decisions

**Why follow `_mt_cd` pattern?**
- Consistency: Users expect similar search behavior across mt commands
- Completeness: Covers modules, packages, functions, and executables
- Proven: The pattern is well-tested and handles edge cases

**Why use `realpath`?**
- Resolves entire symlink chain (not just one level)
- Already a required dependency of metool
- Provides canonical absolute paths

**Output format:**
- Simple: Just the path, nothing else (enables piping and scripting)
- Example: `/Users/admin/Code/github.com/mbailey/metool-packages-dev/tmux/bin/tmux-dev-window`

## Components to Modify

### 1. lib/path.sh
**Location:** `worktree/lib/path.sh`
**Action:** Add new function `_mt_which()`

**Function signature:**
```bash
_mt_which() {
  if (($# != 1)); then
    echo "Usage: mt which <module|package|function|executable>" >&2
    return 1
  fi
  # ... implementation
}
```

**Logic flow:**
```
1. Validate arguments (exactly 1 required)
2. Check for realpath command availability
3. Try module (check MT_MODULES_DIR)
   → If found: realpath the module directory, output, return 0
4. Try package (check MT_PACKAGES_DIR)
   → If found: realpath the package directory, output, return 0
5. Try function (use declare -F)
   → If found: realpath the source file, output, return 0
6. Try executable (use which)
   → If found: realpath the executable, output, return 0
7. Not found: error to stderr, return 1
```

**Key differences from `_mt_cd`:**
- Output path via `echo` instead of `cd`
- For modules/packages: output the directory path itself
- For functions: output the source file path
- For executables: output the resolved executable path

**Error handling:**
- Check realpath availability (same as `_mt_cd`)
- Single argument required
- Clear error message if target not found
- All errors to stderr, return code 1

### 2. shell/mt
**Location:** `worktree/shell/mt`

#### 2a. Add command handler
**Line:** After line 198 (after `cd` command, before `git`)
**Code to add:**
```bash
    which)
      shift
      _mt_which "$@"
      ;;
```

#### 2b. Update help text
**Lines:** 158-189 (Core Commands section)
**Add after `cd` command (line 159):**
```bash
      echo "  which TARGET           Show real path to module, package, function, or executable"
```

**Sort order:** Keep alphabetical within sections where reasonable, but `which` naturally fits after `cd` and before other commands.

### 3. shell/completions/mt.bash
**Location:** `worktree/shell/completions/mt.bash`

#### 3a. Add to command list
**Line:** 54
**Change:**
```bash
  local mt_commands="cd deps doctor edit git module package reload update"
```
**To:**
```bash
  local mt_commands="cd deps doctor edit git module package reload update which"
```

#### 3b. Add completion rule
**Line:** After line 70 (after `edit` completion rule)
**Code to add:**
```bash
  elif [[ ${prev} == "which" ]]; then
    _mt_complete_functions_and_executables
```

**Rationale:** Use same completion as `edit` - both work with functions and executables.

## File Modification Summary

| File | Lines | Action | Details |
|------|-------|--------|---------|
| `lib/path.sh` | End of file (~217) | Add | New `_mt_which()` function (~50 lines) |
| `shell/mt` | ~199 | Add | Command handler (4 lines) |
| `shell/mt` | ~159 | Add | Help text (1 line) |
| `shell/completions/mt.bash` | ~54 | Modify | Add 'which' to command list |
| `shell/completions/mt.bash` | ~71 | Add | Completion rule (2 lines) |

**Total changes:** ~60 lines across 3 files

## Implementation Steps

### Step 1: Implement core function
1. Open `worktree/lib/path.sh`
2. Add `_mt_which()` function at end of file (after `_mt_path_rm`)
3. Follow the logic flow outlined above
4. Match coding style: use `realpath` checks, error messages to stderr
5. Test the function in isolation if possible

### Step 2: Add command handler
1. Open `worktree/shell/mt`
2. Add `which` case after `cd` case (around line 199)
3. Add help text entry (around line 159)
4. Verify case statement syntax

### Step 3: Add shell completion
1. Open `worktree/shell/completions/mt.bash`
2. Add 'which' to `mt_commands` list (line 54)
3. Add completion rule after `edit` rule (line 71)
4. Verify completion logic syntax

### Step 4: Manual testing
1. Source the updated shell/mt: `source worktree/shell/mt`
2. Test each search path:
   - Module: `mt which <module-name>`
   - Package: `mt which <package-name>`
   - Function: `mt which <function-name>`
   - Executable: `mt which <executable-name>`
3. Test error cases:
   - No arguments: `mt which`
   - Too many arguments: `mt which foo bar`
   - Non-existent target: `mt which nonexistent`
4. Test shell completion: `mt which <TAB>`

## Testing Strategy

### Unit Testing
No formal unit test framework exists for metool bash functions. Testing will be manual.

### Manual Test Cases

| Test Case | Command | Expected Output | Notes |
|-----------|---------|-----------------|-------|
| **Module** | `mt which <module>` | Resolved module directory path | If module exists in working set |
| **Package** | `mt which <package>` | Resolved package directory path | If package exists in working set |
| **Function** | `mt which _mt_cd` | Path to lib/path.sh | Built-in function |
| **Executable (symlink)** | `mt which tmux-dev-window` | Real path after resolving symlinks | Example from README |
| **Executable (direct)** | `mt which bash` | Real path to bash | System executable |
| **Not found** | `mt which nonexistent` | Error to stderr, exit 1 | |
| **No args** | `mt which` | Usage message to stderr, exit 1 | |
| **Multiple args** | `mt which foo bar` | Usage message to stderr, exit 1 | |
| **Completion** | `mt which <TAB>` | Shows functions and executables | Tab completion works |
| **Help** | `mt --help` | Includes 'which' in command list | Help text updated |

### Integration Testing
1. Verify `mt which` works from different shells (bash, zsh if applicable)
2. Verify output is clean (no extra formatting) for script use
3. Test pipe usage: `cd $(dirname $(mt which tmux-dev-window))`
4. Compare with `mt cd` behavior for consistency

### Edge Cases
1. **Symlink chains**: Multiple levels of symlinks (e.g., metool bin → packages → repo)
2. **Functions with spaces in path**: Ensure path parsing handles spaces
3. **Case sensitivity**: Function names are case-sensitive
4. **Ambiguity**: If name matches both module and executable, module takes precedence (follows `mt cd` order)

## Code Style Guidelines

Follow existing metool conventions:
- Use `[[ ]]` for conditionals (not `[ ]`)
- Use `$()` for command substitution (not backticks)
- Use `local` for function-scoped variables
- Error messages to stderr: `echo "Error: ..." >&2`
- Use `_mt_log DEBUG` for debug output (already available)
- Return 1 on error, 0 on success
- Match indentation style (2 spaces)

## Dependencies

- **realpath**: Already a required dependency (checked in shell/mt and _mt_cd)
- **which**: Standard command, assumed available
- **declare**: Bash built-in for function introspection
- **compgen**: Bash built-in for completion

No new dependencies required.

## Backwards Compatibility

This is a new command, no backwards compatibility concerns.

## Performance Considerations

- Minimal overhead: Function uses same search pattern as `mt cd`
- No recursion or loops over large datasets
- `realpath` is fast (single syscall)
- Completion uses existing helper functions

Expected performance: Instant (<50ms) for typical use cases.

## Security Considerations

- No user input is passed to eval or similar dangerous constructs
- Paths are properly quoted in all operations
- Uses standard commands (which, realpath, declare)
- No temporary files or network access

## Documentation Updates

### Help Text
Already included in implementation (shell/mt modification).

### README.md (optional)
Consider adding example to task README.md after implementation:
```bash
$ mt which tmux-dev-window
/Users/admin/Code/github.com/mbailey/metool-packages-dev/tmux/bin/tmux-dev-window
```

### Metool CHANGELOG (optional)
After merge, add entry:
```
### Added
- `mt which` command to resolve real paths of modules, packages, functions, and executables
```

## Rollback Plan

If issues are discovered:
1. Remove `which` case from shell/mt
2. Remove `_mt_which` function from lib/path.sh
3. Remove completion rule from shell/completions/mt.bash
4. Revert help text change

Clean rollback: The function is self-contained and doesn't modify existing code.

## Success Criteria

Implementation is complete when:
- ✅ `mt which <executable>` shows resolved real path
- ✅ Works for modules, packages, functions, and executables
- ✅ Shell completion functions correctly
- ✅ Help text includes new command
- ✅ Error messages are clear and helpful
- ✅ All manual test cases pass
- ✅ Behavior is consistent with `mt cd` search order

## Next Steps After Design Approval

1. Proceed to impl-001: Implement the design as specified
2. Follow implementation steps 1-4 sequentially
3. Test each component as it's implemented
4. Commit changes with task ID reference
5. Update harness tracking
