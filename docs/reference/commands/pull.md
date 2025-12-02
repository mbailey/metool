# mt git pull

Fetch and pull updates for git repositories defined in .repos.txt manifest files.

## Usage

```bash
mt git pull [directory|file] [options]
```

## Options

```
-h, --help                Show this help
-q, --quick               Skip updating existing repositories (only clone missing)
-n, --dry-run             Show actions without executing
-p, --protocol PROTOCOL   Git protocol: git or https (default: git)
-v, --verbose             Detailed output
```

## Examples

```bash
# Discover .repos.txt or repos.txt automatically
mt git pull

# Find repos file in external/ directory
mt git pull external/

# Use specific manifest file
mt git pull ~/projects/.repos.txt

# Preview changes with auto-discovery
mt git pull --dry-run

# Only clone missing repos, skip updates
mt git pull --quick

# Use HTTPS instead of SSH
mt git pull --protocol https
```

## File Format

The `repos.txt` or `.repos.txt` file uses a simple whitespace-separated format:

```bash
# Basic format
mbailey/mt-public                     # default target name
vendor/lib@v1.2.3    custom-lib       # custom target name
internal/tools       my-tools         # custom target name

# Multi-account support (requires SSH config)
github.com_work:company/repo  tools   # full host identity
_work:company/repo            tools   # GitHub shorthand
_:mbailey/keycutter                   # auto-match owner as identity
```

## Behavior

**File Discovery**: When no file is specified, searches from current directory up to git root for `.repos.txt` (hidden) then `repos.txt`. Outside git repos, only checks current directory.

**Cloning**: Repositories are cloned to their canonical location under `MT_GIT_BASE_DIR` (default: `~/Code`). A symlink is created in the working directory pointing to the cloned repository.

**Updating**: Existing repositories are fetched and pulled with rebase if behind remote.

**Repository Resolution**:
- `owner/repo` → SSH by default
- `_identity:owner/repo` → GitHub with SSH identity
- Full URLs used as-is

## See Also

- `mt git push` - Push local commits for repositories
- `mt git clone` - Clone a single repository
- `mt git add` - Add repository to .repos.txt
