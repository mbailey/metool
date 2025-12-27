# Creating a Package

Step-by-step guide to creating a new metool package.

## Step 1: Create Directory Structure

```bash
mkdir -p package-name/{bin,shell,config,lib}
```

## Step 2: Create README.md (Required)

Every package must have a README.md:

```markdown
# Package Name

Brief description of what this package provides

## Installation

\`\`\`bash
mt package add module/package-name
mt package install package-name
\`\`\`

## Components

- `bin/tool-name` - Main tool for doing X
- `shell/functions` - Helper functions for Y
- `config/dot-toolrc` - Configuration file

## Usage

[Usage examples]

## Requirements

- bash 4.0+
- other dependencies
```

## Step 3: Add Components

### Executables (bin/)

```bash
cat > package-name/bin/tool-name << 'EOF'
#!/usr/bin/env bash
# Tool description
set -euo pipefail

# Implementation
EOF

chmod +x package-name/bin/tool-name
```

Requirements:
- Must be executable (`chmod +x`)
- Should have shebang line
- Names should be descriptive and unique

### Shell Functions (shell/)

```bash
cat > package-name/shell/functions << 'EOF'
# Function description
function_name() {
    # Implementation
}
EOF
```

Shell directory structure:
- `shell/functions` - Shell functions
- `shell/aliases` - Command aliases
- `shell/completions/` - Bash tab completion
- `shell/environment` - Environment variable exports
- `shell/path` - PATH modifications

### Configuration Files (config/)

Use `dot-` prefix for dotfiles:

```bash
mkdir -p package-name/config
cat > package-name/config/dot-toolrc << 'EOF'
# Configuration
EOF
```

The `dot-` prefix becomes `.` when installed:
- `config/dot-bashrc` → `~/.bashrc`
- `config/dot-config/tool/` → `~/.config/tool/`

## Step 4: Install the Package

```bash
# Add to working set
mt package add module/package-name

# Install (create symlinks)
mt package install package-name

# Reload shell to pick up new functions
mt reload
```

## Adding a Skill (Optional)

To enable AI assistance, create a `SKILL.md` file:

```bash
mt package new my-package /path/to/module
```

This creates a package from template including `SKILL.md.example`. Rename to `SKILL.md` to activate.

See [docs/skills/README.md](../skills/README.md) for skill creation details.

## Best Practices

1. **One Purpose** - Each package should have a clear, focused purpose
2. **Self-Contained** - Packages should work independently
3. **Well-Documented** - Include README and inline documentation
4. **Tested** - Test packages before installing
5. **Dependencies** - Document and check for dependencies

## See Also

- [structure.md](structure.md) - Package directory conventions
- [naming.md](naming.md) - Naming conventions
- [python.md](python.md) - Python script conventions
