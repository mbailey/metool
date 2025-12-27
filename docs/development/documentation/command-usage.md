# Command Documentation

Standards for CLI command help text and reference documentation.

## Two Locations

Command documentation exists in two places:

1. **CLI `--help`** - Built into the command, shown at runtime
2. **docs/reference/commands/** - Markdown files for detailed reference

Both should be consistent but serve different purposes.

## CLI Help Text

The `--help` output users see when running a command.

### Template

```
command-name - Brief one-line description

USAGE:
    command-name [OPTIONS] <ARGUMENTS>

ARGUMENTS:
    <arg>           Description of required argument
    [optional]      Description of optional argument

OPTIONS:
    -h, --help      Show this help
    -v, --verbose   Enable verbose output
    -q, --quiet     Suppress non-error output

EXAMPLES:
    command-name file.txt
        Process a single file

    command-name -v *.txt
        Process all text files with verbose output

ENVIRONMENT:
    VARIABLE_NAME   Description of how it affects behavior
```

### Guidelines

- First line: `command - description` (lowercase, no period)
- Usage: Show actual syntax with brackets for optional
- Arguments: Required in `<angle>`, optional in `[brackets]`
- Options: Short form, long form, description
- Examples: Show common cases with brief explanations
- Keep under 40 lines when possible

### Bash Implementation

```bash
show_help() {
    cat << 'EOF'
mt-example - Brief description of command

USAGE:
    mt-example [OPTIONS] <file>

OPTIONS:
    -h, --help      Show this help
    -v, --verbose   Enable verbose output

EXAMPLES:
    mt-example config.yml
        Process the config file
EOF
}

# In main():
case "$1" in
    -h|--help) show_help; exit 0 ;;
esac
```

## Reference Documentation

Markdown files in `docs/reference/commands/` for detailed reference.

### Template

```markdown
# mt command

Brief description of what the command does.

## Usage

\`\`\`bash
mt command [OPTIONS] <arguments>
\`\`\`

## Description

Detailed explanation of the command's purpose, behavior, and when to use it.

## Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-v, --verbose` | Enable verbose output |
| `--option VALUE` | Description with value |

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<file>` | Yes | The file to process |
| `[output]` | No | Optional output path |

## Examples

### Basic Usage

\`\`\`bash
mt command file.txt
\`\`\`

Description of what this does.

### With Options

\`\`\`bash
mt command --verbose file.txt
# Output: Processing file.txt...
\`\`\`

### Common Workflow

\`\`\`bash
# First, do this
mt command --setup

# Then do this
mt command file.txt
\`\`\`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MT_ROOT` | `~/.metool` | Root directory |
| `EDITOR` | `vi` | Editor for --edit |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |

## Notes

- Important caveats or tips
- Platform-specific behavior
- Performance considerations

## See Also

- [mt related-command](related-command.md) - Description
- [Guide: Common Workflow](../../guides/workflow.md)
```

### Directory Structure

```
docs/reference/commands/
├── README.md       # Index of all commands
├── cd.md
├── edit.md
├── install.md
└── ...
```

### README.md for Commands

```markdown
# Command Reference

All mt commands with brief descriptions.

## Commands

| Command | Description |
|---------|-------------|
| [cd](cd.md) | Change to metool directories |
| [edit](edit.md) | Edit functions and files |
| [install](install.md) | Install packages |

## Categories

### Package Management
- [install](install.md) - Install packages
- [packages](packages.md) - List packages

### Navigation
- [cd](cd.md) - Change directory
- [edit](edit.md) - Edit files
```

## Consistency Between Help and Docs

- Same option names and descriptions
- Same examples (docs can have more)
- Update both when commands change
- Docs can expand on help text but shouldn't contradict

## Subcommands

For commands with subcommands like `mt git`:

### Help Text

```
mt git - Git repository management

USAGE:
    mt git <COMMAND>

COMMANDS:
    add         Add repository to manifest
    pull        Pull all repositories
    push        Push all repositories
    repos       List repositories

Run 'mt git <command> --help' for command-specific help.
```

### Reference Docs

Create a parent file `git.md` that links to subcommand docs:

```markdown
# mt git

Git repository management commands.

## Subcommands

| Command | Description |
|---------|-------------|
| [add](git-add.md) | Add repository to manifest |
| [pull](git-pull.md) | Pull all repositories |

## Common Usage

\`\`\`bash
mt git pull    # Update all repos
mt git push    # Push all changes
\`\`\`
```
