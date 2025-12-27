# Naming Conventions

Naming conventions for metool packages and scripts.

## Package Names

- Use **lowercase with hyphens**
- Be descriptive but concise
- Avoid generic names

### Good Examples

- `git-tools` - Clear purpose
- `docker-helpers` - Descriptive
- `aws-scripts` - Specific domain

### Bad Examples

- `utils` - Too generic
- `MyTools` - Wrong case
- `misc` - Not descriptive
- `stuff` - Meaningless

## Script Names

- Use **lowercase with hyphens**
- Include package prefix if needed for clarity
- Make purpose obvious from name

### Examples

- `git-branch-clean` - Action is clear
- `docker-cleanup` - Domain + action
- `aws-ec2-list` - Service + resource + action

## Function Names

For shell functions in `shell/functions`:

- Use **lowercase with underscores** for internal functions
- Prefix with package name to avoid conflicts

```bash
# Good
git_tools_cleanup_branches() { ... }

# Avoid (might conflict)
cleanup_branches() { ... }
```

## Alias Names

Keep aliases short but memorable:

```bash
# In shell/aliases
alias gbc='git-branch-clean'
alias dcl='docker-cleanup'
```

## Configuration Files

Use `dot-` prefix in `config/`:

- `dot-gitconfig` → `~/.gitconfig`
- `dot-bashrc` → `~/.bashrc`
- `dot-config/tool/` → `~/.config/tool/`

## Module Names

Modules group related packages:

- `metool-packages` - Public packages
- `metool-packages-dev` - Development packages
- `metool-packages-personal` - Personal packages
- `metool-packages-work` - Work-specific packages

## See Also

- [structure.md](structure.md) - Package structure conventions
- [creation.md](creation.md) - Creating packages
