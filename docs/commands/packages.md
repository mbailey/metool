# mt packages

List all metool packages with their parent modules

## Usage

```bash
mt packages [SUBSTRING]
```

## Examples

```bash
# List all packages
mt packages

# Filter packages by substring
mt packages tmux

# Pipe to grep for advanced filtering
mt packages | grep -E '^(git|ssh)'
```

## Description

The `mt packages` command lists all metool packages along with their parent module names. The output is formatted as a table when displayed in a terminal, or as tab-separated values (TSV) when piped to another command.

Output columns:
- **Package Name**: The name of the package directory
- **Module Name**: The parent module containing the package
- **Package Path**: The full path to the package directory

The command discovers packages by examining symlinks in `~/.metool/bin` and `~/.metool/shell` directories. Results are cached for performance and regenerated when package installations change.

## See Also

`mt modules`, `mt components`, `mt install`