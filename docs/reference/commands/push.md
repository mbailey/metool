# mt git push

Push local commits for git repositories defined in .repos.txt manifest files.

## Usage

```bash
mt git push [directory|file] [options]
```

## Options

```
-h, --help      Show this help
-n, --dry-run   Show what would be pushed without executing
-f, --force     Force push (uses --force-with-lease for safety)
-v, --verbose   Detailed output
```

## Examples

```bash
# Push all repos from discovered .repos.txt
mt git push

# Push repos from .repos.txt in directory
mt git push ~/projects/

# Push repos from specific manifest file
mt git push ~/projects/.repos.txt

# Preview what would be pushed
mt git push --dry-run

# Force push (be careful!)
mt git push --force
```

## File Format

Uses the same `.repos.txt` format as `mt git pull`. See `mt git pull --help` for details.

## Behavior

**Safety Features**:
- Repositories with uncommitted changes are skipped
- Repositories that are behind remote are skipped (pull first)
- Repositories that have diverged require `--force` flag
- Force push uses `--force-with-lease` for safety

**Status Messages**:
- `pushed` - Changes pushed to remote
- `current` - Nothing to push, already up to date
- `behind` - Repository behind remote, pull first
- `diverged` - Needs --force or manual merge
- `dirty` - Has uncommitted changes
- `detached` - In detached HEAD state

## See Also

- `mt git pull` - Fetch and pull repositories
- `mt git clone` - Clone a single repository
