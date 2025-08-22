# mt git

Git repository management commands

## Synopsis

```bash
mt git <subcommand> [options]
```

## Description

The `mt git` command provides a suite of tools for managing git repositories, including cloning to canonical locations, discovering existing repositories, syncing from manifest files, and managing repository lists.

## Subcommands

### add

Add a repository to the nearest `.repos.txt` file

```bash
mt git add [REPO] [ALIAS]
```

**Arguments:**
- `REPO` - Repository URL or current directory (default: current)
- `ALIAS` - Custom alias for the repository

**Options:**
- `-y, --yes` - Add without prompting
- `-h, --help` - Show help message

**Environment:**
- `MT_GIT_AUTO_ADD` - Set to 'true' to always add without prompting

**Examples:**
```bash
# Add current repository
mt git add

# Add specific repository
mt git add owner/repo

# Add with custom alias
mt git add owner/repo my-alias

# Add without prompting
mt git add --yes
```

**Behavior:**
- Searches up the directory tree for `.repos.txt`
- Offers to create `.repos.txt` if not found
- Detects and skips duplicate entries
- Converts full URLs to canonical format for storage

### clone

Clone a git repository to a canonical location

```bash
mt git clone <URL> [PATH]
```

**Arguments:**
- `URL` - Git repository URL or shorthand (e.g., 'user/repo')
- `PATH` - Optional custom destination path

**Options:**
- `--include-identity-in-path` - Include SSH identity in canonical paths
- `-h, --help` - Show help message

**Environment:**
- `MT_GIT_PROTOCOL_DEFAULT` - Default protocol (default: git)
- `MT_GIT_HOST_DEFAULT` - Default host (default: github.com)
- `MT_GIT_USER_DEFAULT` - Default user (default: mbailey)
- `MT_GIT_BASE_DIR` - Base directory for repositories (default: ~/Code)

**Examples:**
```bash
# Clone with full URL
mt git clone https://github.com/mbailey/metool

# Clone with shorthand
mt git clone mbailey/metool

# Clone with SSH identity
mt git clone github.com_work:company/repo
```

### repos

List git repositories accessible via symlinks

```bash
mt git repos [OPTIONS]
```

**Options:**
- `-h` - Show only symlinked repositories in home directory
- `-r <path>` - Recursively discover from specified path
- `--help` - Show help message

**Examples:**
```bash
# List repositories in current directory
mt git repos

# List home directory symlinks only
mt git repos -h

# Discover recursively from ~/Code
mt git repos -r ~/Code
```

### sync

Sync repositories from a `.repos.txt` manifest file

```bash
mt git sync [DIR|FILE]
```

**Arguments:**
- `DIR|FILE` - Directory containing `.repos.txt` or specific manifest file

**Behavior:**
- Searches for `.repos.txt` in the specified directory
- Clones missing repositories
- Creates symlinks with specified aliases
- Updates existing repositories (if configured)

**Examples:**
```bash
# Sync from current directory's .repos.txt
mt git sync

# Sync from specific file
mt git sync ~/repos.txt

# Sync from a directory
mt git sync ~/projects/
```

### trusted

Check if a repository is trusted based on URL patterns

```bash
mt git trusted [PATH]
```

**Arguments:**
- `PATH` - Directory to check (default: current directory)

**Options:**
- `-l, --list` - List all trusted patterns
- `-h, --help` - Show help message

**Returns:**
- `TRUSTED` - Repository matches a trusted pattern
- `UNTRUSTED` - Repository does not match any trusted pattern  
- `NOT_GIT` - Directory is not a git repository
- `NO_REMOTE` - Repository has no remote origin

**Examples:**
```bash
# Check current directory
mt git trusted

# Check specific directory
mt git trusted ~/project

# List trusted patterns
mt git trusted --list
```

## Repository Manifest Format

The `.repos.txt` file contains one repository per line:

```
# Comments allowed
owner/repo
owner/repo custom-alias
github.com_identity:owner/repo alias
```

## Canonical Repository Paths

Repositories are cloned to canonical paths under `MT_GIT_BASE_DIR`:

```
~/Code/
├── github.com/
│   ├── mbailey/
│   │   ├── metool/
│   │   └── keycutter/
│   └── ai-cora/
│       └── agents/
└── gitlab.com/
    └── company/
        └── project/
```

## See Also

- [repos](repos.md) - Discover repositories command
- [sync](sync.md) - Repository syncing command
- [clone](clone.md) - Clone command details
- [Repository Management Guide](../../guides/repository-management.md) - Complete workflow guide