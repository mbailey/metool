# mt cd

Change directory to MT_ROOT or the location of a function, executable, or file

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

# Change to directory containing a function
mt cd mt

# Change to directory containing an executable
mt cd git
```

## Description

The `mt cd` command changes the current working directory based on the target provided:

- **Without arguments**: Changes to the MT_ROOT directory (the root of your metool installation)
- **With a function name**: Changes to the directory containing the file where the function is defined
- **With an executable name**: Changes to the directory containing the executable found in PATH

This is particularly useful for quickly navigating to package directories or the location of specific tools and functions.

## See Also

`mt install`, `mt sync`, `mt edit`
