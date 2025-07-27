# Metool Conventions Discovery Guide

This guide helps AI assistants find and follow project conventions before making changes.

## When to Check for Conventions

Always check before:
- Creating new files
- Adding new functions
- Modifying existing patterns
- Changing naming schemes

## How to Discover Conventions

### 1. Function Naming
```bash
# Find function patterns
grep -h "^[[:space:]]*.*() {" lib/*.sh | sort | uniq

# Current patterns:
# - Internal functions: `_mt_function_name`
# - Public commands: implement as `mt subcommand`
```

### 2. Variable Naming
```bash
# Find environment variables
grep -h "export [A-Z_]*=" shell/* lib/*.sh | sort | uniq

# Current patterns:
# - Environment vars: `MT_*` prefix (e.g., MT_ROOT, MT_PKG_DIR)
# - Local vars: lowercase with underscores
```

### 3. File Organization
- Library files: `lib/*.sh` (use .sh extension)
- Shell configs: `shell/*` (no extension)
- Tests: `tests/*.bats` 
- Docs: `docs/` (user), `docs/development/` (internal)

### 4. Error Handling
```bash
# Find error patterns
grep -n "_mt_error\|return [0-9]" lib/*.sh

# Current patterns:
# - Use `_mt_error "message"` for errors
# - Return non-zero on failure
# - Use `return`, never `exit` in sourced files
```

### 5. Before Adding Dependencies
- Check existing: `grep "command -v" lib/*.sh`
- Use `_mt_check_deps` pattern from `lib/deps.sh`
- Add to `mt deps` command if required

### 6. Testing Patterns
- Look at existing tests: `tests/*.bats`
- Use `require_command` for prerequisites
- Compare resolved paths with `realpath` when needed

## Quick Reference Commands

```bash
# Find similar files before creating new ones
find . -name "*.sh" -type f | grep -v ".git"

# Check naming patterns for your use case
grep -r "your_pattern" lib/ shell/

# See how similar features are implemented
grep -A5 -B5 "similar_feature" lib/*.sh
```

## Key Principles

1. **Consistency over perfection** - Follow existing patterns
2. **Check before creating** - Similar functionality may exist
3. **Preserve behavior** - Don't break existing usage
4. **Document unclear patterns** - Add comments when needed

Remember: When in doubt, check how similar things are already done in the codebase.