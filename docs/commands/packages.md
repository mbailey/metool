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

## Install

Install a package by symlinking its components (`bin/`, `config/`, `shell/`, `SKILL.md`) into `~/.metool/`:

```bash
mt package install <package> [<package>...] [options]
```

### Options

- `-h`, `--help` -- Print usage and exit 0.
- `--no-bin`, `--no-config`, `--no-shell`, `--no-skill` -- Skip the named component.
- `--adopt` -- For each `config/` destination that is a regular file (not a symlink), copy its contents back into the package source and then replace the destination with the stow symlink. Scoped to `config/` only.
- `--force` -- Bypass the uncommitted-changes safety guard for `--adopt`. Without `--adopt`, `--force` is parsed but has no effect today (reserved).

`mt package install` (no args), `-h`, and `--help` all print the same usage block.

### Adopt: pulling user-side drift back into a package

When a destination dotfile already exists as a regular file with edits the user wants to keep -- the canonical case being `~/.gitconfig` with a locally-added alias that hasn't made it into `config/dot-gitconfig` yet -- `--adopt` captures that drift instead of erroring on the conflict.

Workflow for the `~/.gitconfig` drift case:

```bash
# Before: ~/.gitconfig is a regular file with a local 'graph' alias
# the package source doesn't have yet.
mt package install git --adopt

# After:
#   - ~/.gitconfig is a symlink into the git package's config/dot-gitconfig
#   - config/dot-gitconfig now contains the home-side content (graph alias included)
#   - per-file output names the review command:
#       adopted: config/dot-gitconfig -- review with: git -C <pkg> diff -- config/dot-gitconfig
git -C <pkg> diff -- config/dot-gitconfig   # review what was adopted
git -C <pkg> commit -m "adopt local graph alias"
```

If `~/.gitconfig` is byte-identical to the source, adopt skips the copy, replaces the file with the symlink, and reports `linked (no change)`. Running `--adopt` a second time on a clean install is a no-op.

### Safety guard

Before any filesystem mutation, adopt checks `git -C <pkg> status --porcelain` against the source paths it would overwrite. If any of them have uncommitted changes, adopt aborts with exit 1 and lists the dirty paths -- nothing on disk has changed yet at that point. Commit or stash the package source, then re-run.

Pass `--force` to skip the guard (the dirty source paths get overwritten by the home-side content). Packages that aren't git repositories are treated as clean and a warning is printed -- there's no review trail in that case.

## See Also

`mt modules`, `mt components`, `mt install`