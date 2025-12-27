# Creating Skills

How to add Claude Code skill support to a metool package.

## Overview

Skills extend Claude Code's capabilities by providing specialized knowledge for a package's domain. When you add a `SKILL.md` file to a package, Claude can load it to understand the package's tools and workflows.

## Quick Start

### Option 1: New Package with Skill

```bash
mt package new my-package /path/to/module
```

This creates a package with `SKILL.md.example`. Rename to `SKILL.md` to activate.

### Option 2: Add Skill to Existing Package

Create `SKILL.md` in the package root:

```markdown
---
name: package-name
description: Brief explanation. This skill should be used when [scenarios].
---

# Package Name

## Overview

[What this package enables]

## Available Tools

- `tool-name` - Description of what the tool does

## Workflows

[Step-by-step procedures]
```

## Installation

When installed via `mt package install`, metool automatically creates symlinks:

1. Package → `~/.metool/skills/<package-name>`
2. `~/.metool/skills/<package-name>` → `~/.claude/skills/<package-name>`

Claude Code discovers skills by scanning `~/.claude/skills/` for `SKILL.md` files.

## Writing Effective Skills

### Content Guidelines

- Focus on **procedural knowledge** Claude cannot infer from code
- Reference package tools by their command names (they're in PATH after install)
- Point to `docs/` files for detailed reference material
- Include concrete examples with realistic scenarios

### Writing Style

Use imperative/infinitive form:

```markdown
# Good
To clean up branches, run `git-branch-clean`.

# Avoid
You should run git-branch-clean to clean up branches.
```

### Size Limits

- Keep SKILL.md under **5k words**
- Move detailed content to `docs/` and link to it
- Use progressive disclosure (see [progressive-disclosure.md](progressive-disclosure.md))

## Human-AI Collaborative Infrastructure

Packages with skills serve both humans and AI:

| For Humans | For AI (Claude) |
|------------|-----------------|
| Scripts in `bin/` - CLI tools | `SKILL.md` - Procedural knowledge |
| Shell functions in `shell/` | Tool references in skill |
| `README.md` - Documentation | `docs/` - Detailed reference |
| `config/` - Settings | Understanding of workflows |

## Validation

Validate package structure and skill:

```bash
mt package validate package-name
```

## See Also

- [structure.md](structure.md) - SKILL.md format requirements
- [progressive-disclosure.md](progressive-disclosure.md) - Token-efficient design
- [../packages/structure.md](../packages/structure.md) - Package structure
