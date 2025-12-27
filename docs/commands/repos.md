# mt repos

Discover and manage git repositories

## Synopsis

```bash
mt repos discover [-r] [PATH]
```

## Description

The `repos` command provides tools for discovering and managing git repositories. Currently supports discovering repositories via symlinks to generate repos.txt format output.

## Subcommands

### discover

Discovers git repositories accessible via symlinks and outputs them in repos.txt format.

```bash
mt repos discover [-r] [PATH]
```

Options:
- `-r, --recursive` - Recursively scan subdirectories
- `PATH` - Directory to scan (default: current directory)

The command:
1. Finds all symlinks in the specified directory
2. Checks if they point to git repositories
3. Extracts the remote origin URL
4. Parses owner/repo from the URL
5. Outputs in repos.txt format: `owner/repo alias`

## Output Format

The output follows the repos.txt format used by `mt sync`:

```
owner/repo alias
```

Where:
- `owner/repo` is extracted from the git remote origin URL
- `alias` is the relative path to the symlink

## Examples

### Discover in Current Directory

```bash
$ mt repos discover
mbailey/metool metool
mbailey/keycutter keycutter
ai-cora/agents agents
```

### Recursive Discovery

```bash
$ mt repos discover -r ~/Code
mbailey/metool Code/tools/metool
ai-cora/agents Code/ai/agents
mbailey/keycutter Code/security/keycutter
```

### Create repos.txt

```bash
# Create new repos.txt
$ mt repos discover -r > repos.txt

# Append to existing
$ mt repos discover -r >> repos.txt
```

### Discover from Home Directory

```bash
$ mt repos discover -r ~/ > ~/repos.txt
```

## URL Format Support

The command supports various git URL formats:

- SSH: `git@github.com:owner/repo.git`
- HTTPS: `https://github.com/owner/repo.git`
- Keycutter aliases: `git@github.com_ai-cora:owner/repo.git`
- URLs without .git suffix

## Notes

- Only symlinks pointing to git repositories with remote origins are included
- Broken symlinks are silently skipped
- Repositories without remotes are silently skipped
- Output is sorted and deduplicated

## See Also

- [mt sync](sync.md) - Sync repositories from repos.txt
- [mt clone](clone.md) - Clone a repository to canonical location