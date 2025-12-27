# Progressive Disclosure

Token-efficient patterns for skill design.

## The Problem

Claude Code has limited context. Loading a large skill wastes tokens on content that may not be needed for the current task.

## Three-Level Loading

Skills use progressive disclosure with three levels:

| Level | Content | When Loaded | Size Target |
|-------|---------|-------------|-------------|
| 1. Metadata | name + description | Always in context | ~100 words |
| 2. SKILL.md | Quick reference | When skill triggers | <5k words |
| 3. docs/ | Detailed content | On demand | Unlimited |

### Level 1: Metadata

Always visible in skill listings. Used to decide whether to load the skill.

```yaml
---
name: git-tools
description: Git workflow utilities. This skill should be used when cleaning up branches or managing worktrees.
---
```

### Level 2: SKILL.md Body

Loaded when the skill is triggered. Should be a navigation layer:

- Brief overview of capabilities
- Most common commands (Pareto principle: 20% used 80% of time)
- Links to detailed docs

### Level 3: docs/ Directory

Loaded only when Claude needs specific details:

```markdown
For complete branch cleanup options, see [docs/branch-cleanup.md](docs/branch-cleanup.md).
```

## Design Principles

### SKILL.md as Navigation Layer

**Key insight:** SKILL.md should contain NO unique content. Everything should exist in docs/ or README.md.

Benefits:
- Humans maintain content in docs/ where they can review it
- Skills stay small and focused
- No duplication between SKILL.md and docs

### Topic Block Pattern

Each topic in SKILL.md follows this pattern:

1. **What & Why** - One sentence
2. **Link to docs** - Must be a file, not directory
3. **Common command** (optional) - Only most-used

Example:
```markdown
### Branch Cleanup

Remove merged branches to keep repository clean.

See [docs/packages/branch-cleanup.md](docs/packages/branch-cleanup.md) for options.

\`\`\`bash
git-branch-clean    # Remove merged branches
\`\`\`
```

### Pareto Principle for Commands

Only include commands used 80% of the time. Detailed command reference goes in docs/.

```markdown
## Essential Commands

\`\`\`bash
git-branch-clean     # Most common
git-worktree-list    # Frequently used
\`\`\`

For all commands, see [docs/commands/README.md](docs/commands/README.md).
```

## Link Requirements

Links must always target a specific markdown file, not a directory:

```markdown
# Good
See [docs/skills/README.md](docs/skills/README.md)

# Bad
See [docs/skills/](docs/skills/)
```

## Size Guidelines

| Component | Target Size |
|-----------|-------------|
| Frontmatter description | <200 characters |
| SKILL.md total | <5k words |
| Individual docs | As needed |

## Refactoring Large Skills

If SKILL.md exceeds 5k words:

1. Identify sections that are reference material
2. Move to appropriate docs/ location
3. Replace with brief summary + link
4. Keep only navigation and common commands in SKILL.md

## See Also

- [creating.md](creating.md) - Creating skills
- [structure.md](structure.md) - SKILL.md format
