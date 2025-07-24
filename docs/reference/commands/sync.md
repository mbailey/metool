# mt sync

Clones and updates git repositories defined in repos.txt manifest files.

## Usage

```bash
mt sync [directory|file] [options]
```

## Options

```
-h, --help                Show this help
--file FILE               Specific repos file name (overrides discovery)
--dry-run                 Show actions without executing
--default-strategy STRAT  Default strategy: shared or local (default: shared)
--protocol PROTOCOL       Git protocol: git or https (default: git)
--verbose                 Detailed output
--force                   Overwrite existing local repositories
```

## Examples

```bash
# Discover .repos.txt or repos.txt automatically
mt sync

# Find repos file in external/ directory
mt sync external/

# Preview changes with auto-discovery
mt sync --dry-run

# Use specific file name
mt sync --file deps.txt

# Use HTTPS instead of SSH
mt sync --protocol https
```

## File Format

The `repos.txt` or `.repos.txt` file uses a simple whitespace-separated format:

```bash
# Basic format
mbailey/mt-public                     # default name, shared strategy
vendor/lib@v1.2.3    custom-lib       # custom name, shared
internal/tools       my-tools  local  # local strategy

# Multi-account support (requires SSH config)
github.com_work:company/repo  tools   # full host identity
_work:company/repo            tools   # GitHub shorthand
_:mbailey/keycutter                   # auto-match owner as identity
```

## Behavior

**File Discovery**: When no file is specified, searches from current directory up to git root for `.repos.txt` (hidden) then `repos.txt`. Outside git repos, only checks current directory.

**Strategies**:
- `shared`: Symlinks from canonical `mt clone` location (default)
- `local`: Clones directly to working directory

**Repository Resolution**:
- `owner/repo` → SSH by default
- `_identity:owner/repo` → GitHub with SSH identity
- Full URLs used as-is

## See Also

`mt clone`, `mt modules` (planned)

For detailed specifications including multi-account setup, see: `docs/specs/sync/README.md`