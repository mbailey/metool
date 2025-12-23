# Package Promotion Workflow

Promote packages between metool modules (e.g., dev → pub) safely.

## Overview

When developing packages, you typically work in a private module (like `dev`) and promote stable, reviewed packages to a public module (like `pub`). This workflow ensures:

- Private content doesn't accidentally get published
- Changes are reviewed before promotion
- Clear separation between development and production packages

## Quick Reference

```bash
# Compare packages between modules
mt package diff tmux dev pub

# Show detailed content differences
mt package diff tmux dev pub --content

# Check if packages differ (scripting)
mt package diff tmux dev pub --quiet && echo "identical" || echo "different"
```

## Step-by-Step Workflow

### 1. Compare Packages

See what differs between your development and public versions:

```bash
mt package diff <package> <from-module> <to-module>
```

Example output:
```
Comparing: tmux
  From: /path/to/metool-packages-dev/tmux
  To:   /path/to/metool-packages/tmux

Only in dev/tmux: AI.md
Only in dev/tmux: SKILL.md
Only in dev/tmux/bin: tmux-cheat
Only in dev/tmux/bin: tmux-dev-window
```

### 2. Review for Sensitive Content

Before promoting, check for:
- Hardcoded paths with usernames
- API keys or tokens
- Internal hostnames or IP addresses
- Private configuration
- Work-specific references

Use `--content` flag to see actual file contents:

```bash
mt package diff tmux dev pub --content | less
```

### 3. Promote Files

#### Option A: Promote Entire Package

If the package doesn't exist in target:

```bash
cp -r ~/.metool/modules/dev/tmux ~/.metool/modules/pub/
```

#### Option B: Promote Specific Files

Copy only the files you want to promote:

```bash
# Single file
cp ~/.metool/modules/dev/tmux/bin/tmux-cheat \
   ~/.metool/modules/pub/tmux/bin/

# Entire directory
cp -r ~/.metool/modules/dev/tmux/bin/* \
      ~/.metool/modules/pub/tmux/bin/
```

#### Option C: Selective Sync with rsync

Use rsync for more control:

```bash
# Sync bin directory, excluding specific files
rsync -av --exclude='*.private' \
  ~/.metool/modules/dev/tmux/bin/ \
  ~/.metool/modules/pub/tmux/bin/
```

### 4. Commit Changes

Navigate to the target module and commit:

```bash
cd ~/.metool/modules/pub
git add tmux/
git commit -m "Promote tmux package updates from dev"
git push
```

### 5. Verify

Run diff again to confirm promotion:

```bash
mt package diff tmux dev pub
# Should show fewer or no differences
```

## Best Practices

### Security First

- **Never promote blindly** - Always review diffs first
- **Check for secrets** - Look for API keys, passwords, tokens
- **Scrub paths** - Replace absolute paths with relative or environment variables
- **Review commit history** - Check what changed before promoting

### Structured Workflow

1. **Develop in dev** - All experimental work stays in dev module
2. **Stabilize** - Test thoroughly before promotion
3. **Review** - Use `mt package diff --content` to check everything
4. **Promote** - Copy only approved files
5. **Document** - Update README if behavior changes

### Keep Modules Clean

- **dev**: All development packages, can contain private content
- **pub**: Public-safe packages only
- **wsl/work**: Work-specific packages that sync from pub

## Common Patterns

### New Package Promotion

When promoting a brand new package:

```bash
# Check it doesn't exist in pub
mt package diff my-package dev pub
# Output: "Package 'my-package' exists in dev but not in pub"

# Copy entire package
cp -r ~/.metool/modules/dev/my-package ~/.metool/modules/pub/

# Remove any private files
rm ~/.metool/modules/pub/my-package/docs/private-notes.md

# Commit
cd ~/.metool/modules/pub
git add my-package/
git commit -m "Add my-package from dev"
```

### Updating Existing Package

When updating files in an existing package:

```bash
# See what changed
mt package diff my-package dev pub

# Review content
mt package diff my-package dev pub --content

# Promote specific files
cp ~/.metool/modules/dev/my-package/bin/new-script \
   ~/.metool/modules/pub/my-package/bin/

# Commit
cd ~/.metool/modules/pub
git add my-package/bin/new-script
git commit -m "Add new-script to my-package"
```

### Scripted Promotion Check

For CI or automation:

```bash
#!/bin/bash
# Check if packages are in sync
for pkg in tmux git-tools docker-helpers; do
  if ! mt package diff "$pkg" dev pub --quiet 2>/dev/null; then
    echo "WARN: $pkg has unpromoted changes"
  fi
done
```

## Troubleshooting

### Module Not Found

```
Error: Module not found in working set: dev
```

Add the module first:
```bash
mt module add dev
```

### Package Not Found

```
Error: Package not found in dev: my-package
```

Check the package exists:
```bash
ls ~/.metool/modules/dev/ | grep my-package
```

### Permission Denied

When copying to pub module:
```bash
# Check module path permissions
ls -la ~/.metool/modules/pub/
```
