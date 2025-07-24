# mt update

Update metool itself from the git repository

## Usage

```bash
mt update
```

## Options

```
-h, --help     Show this help
```

## Examples

```bash
# Update metool to the latest version
mt update
```

## Description

The `mt update` command performs a self-update of metool by pulling the latest changes from the git repository.

The update process:
- Verifies MT_ROOT is a git repository
- Checks the current branch (updates only occur on master branch)
- Fetches latest changes from origin
- Pulls updates if available

The command will skip updates if:
- MT_ROOT is not a git repository
- You're not on the master branch
- There are no updates available

## See Also

`mt sync`, `mt install`, `mt reload`