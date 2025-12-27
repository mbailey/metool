# mt components

List all package components across metool packages

## Usage

```bash
mt components [PACKAGE]
```

## Examples

```bash
# List all components from all packages
mt components

# List components for a specific package
mt components git
```

## Description

The `mt components` command displays all available components (bin, shell, config, docs, lib, libexec) found in metool packages. The output shows:

- **COMPONENT**: The type of component (bin, shell, config, etc.)
- **PACKAGE**: The package name containing the component
- **MODULE**: The parent module containing the package
- **PATH**: The full path to the component directory

This command is useful for discovering what resources are available across your metool installation and understanding the structure of packages.

## See Also

`mt packages`, `mt modules`, `mt install`