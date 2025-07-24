# mt clone

Clone a git repository to a canonical location

## Usage

```bash
mt clone [options] <git_repo> [<destination_path>]
```

## Options

```
--include-identity-in-path  Include SSH identity in canonical paths
-h, --help                  Show this help
```

## Examples

```bash
# Clone using full URL
mt clone https://github.com/mbailey/metool

# Clone using shorthand notation
mt clone mbailey/metool

# Clone to a custom destination
mt clone user/repo /custom/path

# Clone with SSH identity in path
mt clone --include-identity-in-path github.com_work:company/repo
```

## Description

The `mt clone` command clones git repositories to canonical locations under your configured base directory. If the repository already exists at the target location, it displays the repository status instead of cloning.

By default, repositories are cloned to `~/Code/{host}/{user}/{repo}`. The base directory can be customized using the `MT_GIT_BASE_DIR` environment variable.

## Environment Variables

- `MT_GIT_BASE_DIR` - Base directory for repositories (default: ~/Code)
- `MT_GIT_HOST_DEFAULT` - Default host (default: github.com)
- `MT_GIT_INCLUDE_IDENTITY_IN_PATH` - Include SSH identity in paths (default: false)
- `MT_GIT_PROTOCOL_DEFAULT` - Default protocol (default: git)
- `MT_GIT_USER_DEFAULT` - Default user (default: mbailey)

## See Also

`mt sync`, `mt update`
