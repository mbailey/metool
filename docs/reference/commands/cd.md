# mt cd

Change directory to MT_ROOT, a module, package, function, or executable

## Usage

```bash
mt cd [TARGET]
```

## Options

```
-h, --help     Show this help
```

## Examples

```bash
# Change to MT_ROOT directory
mt cd

# Change to a module directory
mt cd metool-packages

# Change to a package directory
mt cd git-tools

# Change to directory containing a function
mt cd mt

# Change to directory containing an executable
mt cd git
```

## Description

The `mt cd` command changes the current working directory based on the target provided:

- **Without arguments**: Changes to the MT_ROOT directory (the root of your metool installation)
- **With a module name**: Changes to the module directory in your working set (`~/.metool/modules/`)
- **With a package name**: Changes to the package directory in your working set (`~/.metool/packages/`)
- **With a function name**: Changes to the directory containing the file where the function is defined
- **With an executable name**: Changes to the directory containing the executable found in PATH

The lookup order is: modules → packages → functions → executables. Symlinks are resolved to navigate to the actual directory.

This is particularly useful for quickly navigating to package directories for development.

## See Also

`mt module list`, `mt package list`, `mt edit`
