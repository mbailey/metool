# Metool Commands Reference

Alphabetical index of all mt commands:

- [cd](cd.md) - Change directory to MT_ROOT or location of function/executable/file
- [clone](clone.md) - Clone a git repository to canonical location
- [components](components.md) - List all package components
- [disable](disable.md) - Disable systemd services while preserving service files
- [edit](edit.md) - Edit functions, executables, packages, or files
- [enable](enable.md) - Enable systemd services from a package
- [install](install.md) - Symlink package directories (bin, config, shell)
- [modules](modules.md) - List all metool modules
- [packages](packages.md) - List all metool packages
- [reload](reload.md) - Reload metool after updates
- [sync](sync.md) - Sync repositories from manifest files
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
- `mt clone` - Clone repositories
- `mt sync` - Sync from manifest files

### Maintenance
- `mt update` - Update metool
- `mt reload` - Reload after changes

## Getting Help

All commands support the `-h` or `--help` flag for quick help:

```bash
mt <command> --help
```