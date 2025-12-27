# mt edit

Edit functions, executables, or files

## Usage

```bash
mt edit <target>
```

## Description

The `edit` command intelligently locates and opens the appropriate file based on the target type:

- **Files** - Opens the specified file directly (checked first)
- **Functions** - Opens the file containing the function definition at the exact line
- **Executables** - Opens the executable file found in PATH

## Target Types

### Files

Direct file editing (including paths with slashes):

```bash
mt edit ~/.bashrc         # Edit configuration files
mt edit /tmp/notes.txt    # Edit any accessible file
mt edit lib/functions.sh  # Edit relative path files
```

### Functions

Edit shell functions at their definition:

```bash
mt edit _mt_sync          # Opens function definition
mt edit my_helper         # Jump to exact line in source file
```

### Executables

Edit scripts in your PATH:

```bash
mt edit git-status-all    # Opens executable for editing
mt edit my-script         # Edit any executable in PATH
```

## Examples

```bash
# Edit a file by path
mt edit docs/README.md
# Opens: the specified file

# Edit an existing function
mt edit _mt_path_prepend
# Opens: lib/path.sh at line 5

# Edit an executable
mt edit mt
# Opens: the mt executable script

# Edit a file with absolute path
mt edit /etc/hosts
# Opens: the specified file (if accessible)
```

## Environment Variables

- `EDITOR` - Preferred text editor (defaults to vim)
- `MT_ROOT` - Metool root directory

## Notes

- VS Code users benefit from line-specific navigation (opens at exact function line)
- The command searches in order: files → functions → executables
- Paths containing slashes are always treated as file paths