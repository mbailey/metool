# mt modules

List all metool modules (collections of packages).

## Usage

```bash
mt modules
```

## Description

The `modules` command displays all metool modules discovered from installed packages. A module is a collection of related packages, typically stored in a common parent directory.

## Output Format

- Tab-separated values when piped
- Aligned columns when displayed in terminal
- Module name and path to module directory

## How It Works

1. Scans `~/.metool/bin` and `~/.metool/shell` for symlinks
2. Traces symlinks back to their source packages
3. Identifies parent directories as modules
4. Caches results for performance

## Examples

```bash
# List all modules
mt modules

# Filter modules
mt modules | grep vim

# Show module count
mt modules | wc -l
```

## Notes

- Results are cached in `~/.metool/.cache/modules.tsv`
- Cache is automatically invalidated when packages change
- The metool repository itself is always included as a module

## See Also

`mt packages`, `mt components`, `mt install`