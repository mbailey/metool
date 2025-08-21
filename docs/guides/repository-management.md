# Repository Management Guide

This guide explains how to use metool's repository management features to capture and recreate your development environment across machines.

## Overview

The repository management workflow consists of two main commands:
- `mt repos discover` - Find and document existing repositories
- `mt sync` - Clone repositories from a manifest file

Together, these commands enable you to:
1. Capture your current repository structure
2. Document it in a portable format
3. Recreate the same structure on another machine

## Workflow

### 1. Discovering Repositories

Use `mt repos discover` to find all git repositories accessible via symlinks:

```bash
# Discover repos in current directory
mt repos discover

# Discover recursively from home directory
mt repos discover -r ~/

# Save to repos.txt
mt repos discover -r ~/Code > repos.txt
```

The command outputs in the format:
```
owner/repo alias
mbailey/metool tools/metool
ai-cora/agents ai/agents
```

### 2. Creating a Repository Manifest

The `repos.txt` file serves as your repository manifest. You can:
- Generate it automatically with `mt repos discover`
- Edit it manually to add/remove repositories
- Organize repositories with meaningful aliases

Example `repos.txt`:
```
# Core tools
mbailey/metool tools/metool
mbailey/keycutter security/keycutter

# AI projects
ai-cora/agents ai/agents
ai-cora/fastmcp ai/fastmcp

# Documentation
mbailey/ai_docs docs/ai_docs
```

### 3. Syncing Repositories

On a new machine, use `mt sync` to clone all repositories:

```bash
# Sync from repos.txt in current directory
mt sync

# Sync from specific file
mt sync ~/repos.txt

# Sync from a specific directory
mt sync ~/projects/
```

The sync command will:
- Clone missing repositories
- Create symlinks with the specified aliases
- Update existing repositories (if present)

## Setting Up a New Machine

Complete workflow for setting up a new development machine:

1. **On the old machine**, capture your repository structure:
   ```bash
   mt repos discover -r ~/Code > ~/repos.txt
   ```

2. **Transfer `repos.txt`** to the new machine (via git, cloud storage, etc.)

3. **On the new machine**, recreate the structure:
   ```bash
   # Install metool first
   git clone https://github.com/mbailey/metool ~/.metool-source
   source ~/.metool-source/shell/mt
   mt install
   
   # Sync repositories
   mt sync ~/repos.txt
   ```

## SSH Key Management

If you use different SSH keys for different GitHub accounts (via keycutter or similar):

1. The discovered URLs will include the key identifier (e.g., `git@github.com_ai-cora`)
2. Ensure your git config has the appropriate `url.*.insteadOf` rules
3. Set up the same SSH key configuration on the new machine

## Advanced Usage

### Filtering Discoveries

To discover only specific types of repositories:

```bash
# Find only in certain directories
mt repos discover -r ~/work/
mt repos discover -r ~/personal/

# Combine multiple discoveries
(
  mt repos discover -r ~/work/
  mt repos discover -r ~/personal/
) | sort | uniq > repos.txt
```

### Organizing by Category

Create separate manifest files for different purposes:

```bash
# Work projects
mt repos discover -r ~/work/ > work-repos.txt

# Personal projects
mt repos discover -r ~/personal/ > personal-repos.txt

# Sync selectively
mt sync work-repos.txt  # Just work projects
mt sync personal-repos.txt  # Just personal projects
```

### Maintaining Multiple Environments

Keep environment-specific repository lists:

```bash
repos/
├── laptop-repos.txt     # Full development setup
├── server-repos.txt     # Minimal server setup
└── ci-repos.txt         # CI/CD required repos
```

## Troubleshooting

### No Repositories Found

If `mt repos discover` returns no results:
- Ensure you have symlinks pointing to git repositories
- Check that repositories have remote origins configured
- Use the correct path to scan

### Sync Failures

If `mt sync` fails to clone:
- Verify SSH keys are configured correctly
- Check network connectivity to git hosts
- Ensure repository URLs are valid

### Symlink Issues

If symlinks aren't created as expected:
- Check that target directories exist
- Verify you have write permissions
- Look for naming conflicts

## Best Practices

1. **Regular Updates**: Periodically run `mt repos discover` to update your manifest
2. **Version Control**: Keep `repos.txt` in a git repository for history
3. **Documentation**: Comment your repos.txt file to explain groupings
4. **Backup**: Keep multiple copies of your repository manifest
5. **Test Recovery**: Periodically test recreating your environment

## Integration with Other Tools

### With keycutter

If using keycutter for SSH key management:
```bash
# URLs will include key identifiers
git@github.com_work:company/project work/project
git@github.com_personal:user/hobby personal/hobby
```

### With dotfiles

Include repos.txt in your dotfiles repository:
```bash
dotfiles/
├── repos.txt
├── .bashrc
└── .gitconfig
```

### With metool packages

Create a package that includes your repos.txt:
```bash
my-repos/
├── README.md
├── config/
│   └── repos.txt
└── shell/
    └── aliases  # Alias to sync: alias sync-repos='mt sync ~/.config/repos.txt'
```

## See Also

- [mt repos](../reference/commands/repos.md) - Command reference for repos discovery
- [mt sync](../reference/commands/sync.md) - Command reference for repository syncing
- [mt clone](../reference/commands/clone.md) - Clone individual repositories