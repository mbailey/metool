# mt reload

Reload metool by re-sourcing the mt shell script.

## Usage

```bash
mt reload
```

## Description

The `mt reload` command re-sources the metool shell script to apply any configuration changes or updates without starting a new shell session. This is useful after:

- Installing new packages with `mt install`
- Updating metool with `mt update`
- Modifying shell aliases or functions
- Changing metool configuration

## Examples

```bash
# Reload after installing a new package
mt install ~/projects/my-tools
mt reload

# Reload after updating metool
mt update
mt reload

# Reload after modifying configuration
vim ~/.metool/shell/custom-aliases
mt reload
```

## Technical Details

The reload command calls `_mt_source` on the main mt shell script, which:
- Re-sources all metool library files
- Re-loads package shell scripts from `~/.metool/shell`
- Updates shell completions and aliases
- Preserves your current directory and shell state

## See Also

`mt update`, `mt install`