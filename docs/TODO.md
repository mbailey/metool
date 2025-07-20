# metool TODO

## Completed

- Added standardized confirmation prompts with consistent interface
  - Single item: `"(Y)eah/(N)ah/(A)bort/(D)on't ask again [YEAH]:"`
  - Multiple items: `"(Y)eah/(N)ah/(A)ll/(Q)uit/(D)on't ask again [YEAH]:"`
  - Color highlighting for options
  - Support for persistent choices via environment variables
- Improved `mt clone` to show repository status when the destination already exists
- Enhanced symlink handling to check if existing symlinks point to the correct destination
- Added bats tests for the `mt clone` command with test infrastructure
- Added bats tests for the `mt install` command
- Modified `mt install` to place config/ files in ~/.metool/config/ first before linking to $HOME
- Added interactive conflict resolution for `mt install` that shows details about existing files and offers to fix issues
- Added clear error messages when trying to install from non-existent directories
- Used `command stow` to bypass any user-defined aliases for stow
- Removed unnecessary grc references from the codebase

## Allow shorter names

Instead of:

```text
mt clone git@github.com_mbailey:mbailey/mt-public.git
```

Accept:

```shell
mt clone mbailey/mt-public
```

- Default to ssh: If user has that access. Maybe try first?

## Add `mt install -r``

Add alternative to mt install `mt-public/*`.

## Add support for `mt install` to clone repo

```shell
mt install mbailey/mt-public
```
