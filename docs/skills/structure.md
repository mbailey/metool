# SKILL.md Structure

Format and requirements for SKILL.md files.

## File Location

```
package-name/
├── README.md     # Human documentation
├── SKILL.md      # AI skill (Claude Code)
└── ...
```

## Required Frontmatter

Every SKILL.md must start with YAML frontmatter:

```yaml
---
name: package-name
description: Brief explanation. This skill should be used when [scenarios].
---
```

### name

- Must be **hyphen-case** (lowercase letters, digits, hyphens only)
- Should match the package name
- Examples: `git-tools`, `docker-helpers`, `my-package`

### description

- Clear explanation of when Claude should use this skill
- Use **third-person** ("This skill should be used when...")
- Include specific trigger scenarios
- Keep under 200 characters for the skill list

Example:
```yaml
description: Git workflow utilities. This skill should be used when cleaning up branches, managing worktrees, or automating git operations.
```

## Recommended Sections

```markdown
---
name: package-name
description: ...
---

# Package Name

## Overview

[1-2 sentences about what this enables]

## When to Use

[Specific triggers and use cases - bulleted list]

## Available Tools

[List of commands with brief descriptions]

## Workflows

[Step-by-step procedures for common tasks]

## See Also

[Links to related docs and packages]
```

## Section Guidelines

### Overview

Brief, focused description:

```markdown
## Overview

Git branch management tools for cleaning merged branches and maintaining worktrees.
```

### When to Use

Specific scenarios that trigger skill loading:

```markdown
## When to Use

- Cleaning up merged or stale branches
- Managing git worktrees
- Automating branch operations
```

### Available Tools

Command reference with descriptions:

```markdown
## Available Tools

- `git-branch-clean` - Remove merged local branches
- `git-worktree-list` - List all worktrees with status
```

### Workflows

Step-by-step procedures:

```markdown
## Workflows

### Cleaning Up After Feature Merge

1. Ensure feature is merged: `git log main --oneline | head -5`
2. Run cleanup: `git-branch-clean`
3. Verify: `git branch`
```

## Anti-Patterns

### Avoid Duplicating README

```markdown
# Bad - duplicates README content
## Installation
\`\`\`bash
mt package install git-tools
\`\`\`
```

Installation belongs in README.md, not SKILL.md.

### Avoid Second Person

```markdown
# Bad
You should run git-branch-clean to clean branches.

# Good
To clean branches, run `git-branch-clean`.
```

### Avoid Excessive Detail

```markdown
# Bad - too detailed for SKILL.md
Here is a 500-line explanation of git internals...

# Good
For git internals, see [docs/git-internals.md](docs/git-internals.md).
```

## See Also

- [creating.md](creating.md) - How to create skills
- [progressive-disclosure.md](progressive-disclosure.md) - Size management
