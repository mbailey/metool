# Metool Commands Reference

Alphabetical index of all mt commands:

- [cd](cd.md) - Change directory to MT_ROOT or location of function/executable/file
- [clone](clone.md) - Clone a git repository to canonical location
- [components](components.md) - List all package components
- [disable](disable.md) - Disable systemd services while preserving service files
- [edit](edit.md) - Edit functions, executables, packages, or files
- [enable](enable.md) - Enable systemd services from a package
- [git](git.md) - Git repository management commands
- [install](install.md) - Symlink package directories (bin, config, shell)
- [modules](modules.md) - List all metool modules
- [packages](packages.md) - List all metool packages
- [pull](pull.md) - Fetch and pull repositories from manifest files
- [push](push.md) - Push local commits for repositories in manifest files
- [reload](reload.md) - Reload metool after updates
- [repos](repos.md) - Discover and manage git repositories
- [update](update.md) - Update metool from git

## Command Categories

### Package Management
- `mt install` - Install packages
- `mt modules` - List modules
- `mt packages` - List packages
- `mt components` - List package components

### Service Management
- `mt enable` - Enable systemd services
- `mt disable` - Disable systemd services

### Development
- `mt edit` - Edit files and functions
- `mt cd` - Navigate to locations

### Repository Management
- `mt git` - Git repository management (add, clone, pull, push, repos, trusted)
- `mt git pull` - Fetch and pull repositories from manifest files
- `mt git push` - Push local commits for repositories
- `mt clone` - Clone repositories
- `mt repos` - Discover repositories

### Maintenance
- `mt update` - Update metool
- `mt reload` - Reload after changes

## Getting Help

All commands support the `-h` or `--help` flag for quick help:

```bash
mt <command> --help
```