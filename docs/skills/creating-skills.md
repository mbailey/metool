# Creating Claude Code Skills

This guide covers creating SKILL.md files for metool packages to enable AI assistance.

## What Skills Provide

Skills extend Claude's capabilities by providing specialized knowledge, workflows, and tools:

1. **Specialized workflows** - Multi-step procedures for specific domains
2. **Tool integrations** - Instructions for working with specific file formats or APIs
3. **Domain expertise** - Package-specific knowledge, schemas, conventions
4. **Bundled resources** - Scripts, docs, and assets accessible to Claude

## Human-AI Collaborative Infrastructure

Metool packages with skills create infrastructure that serves both humans and AI:

**For Humans:**
- Scripts in `bin/` provide CLI tools available in PATH
- Shell functions and aliases in `shell/` enhance interactive workflows
- Configuration in `config/` manages dotfiles and settings
- `README.md` documents the package for human users

**For AI (Claude):**
- `SKILL.md` provides procedural knowledge and workflow guidance
- References to `bin/` scripts tell Claude what tools are available
- Documentation in `docs/` enables progressive disclosure
- Understanding of `shell/` functions helps Claude guide interactive usage

**Shared Benefits:**
- The `docs/` directory serves both as reference material for Claude and documentation for humans
- Tools created in `bin/` are immediately useful to humans while being discoverable and executable by Claude
- The package grows organically as both human and AI collaborate

## SKILL.md Structure

Every skill requires a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: package-name
description: Brief explanation of what the skill does and when to use it. This skill should be used when [specific scenarios].
---

# Package Name

## Overview

[1-2 sentences explaining what this skill enables]

## When to Use

[Specific triggers and use cases]

## Workflows

[Step-by-step procedures, tool references, examples]

## Resources

[References to bin/ scripts, docs/ files, and other package components]
```

**Frontmatter Requirements:**
- `name`: Must be hyphen-case (lowercase letters, digits, hyphens only)
- `description`: Clear explanation of when Claude should use this skill. Use third-person ("This skill should be used when..." not "Use this skill when...")

## Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata** (~100 words) - Always in context (name + description)
2. **SKILL.md body** (<5k words) - Loaded when skill triggers
3. **Package resources** (unlimited) - Loaded as needed by Claude

Scripts in `bin/` can be executed without loading into context, making them token-efficient.

## Adding a Skill to an Existing Package

When adding a skill to an existing metool package:

1. **Create only the SKILL.md file** - Do not overwrite existing README.md or other files
2. **Reference existing tools** - Review what scripts, functions, and docs already exist
3. **Adapt to existing structure** - The SKILL.md should work with the package's current organization

Example: Adding a skill to a `git-tools` package that already has `bin/git-branch-clean`:

```markdown
---
name: git-tools
description: Git workflow utilities for branch management and repository maintenance. This skill should be used when cleaning up git branches, managing worktrees, or automating git workflows.
---

# Git Tools

## Overview

Provides utilities for git branch management and repository maintenance.

## Available Tools

- `git-branch-clean` - Remove merged local branches
- `git-worktree-list` - List all worktrees with status

## Workflows

### Cleaning Up Branches

To clean up merged branches, run:
\`\`\`bash
git-branch-clean
\`\`\`
```

## Creating a New Package with Skill

To create a new metool package with skill support:

```bash
mt package new my-package /path/to/module
```

This creates a package from the template including `SKILL.md.example`:
```
my-package/
├── README.md           # Human documentation template
├── SKILL.md.example    # Claude skill template (rename to SKILL.md to activate)
├── bin/                # Executable scripts directory
├── shell/              # Shell functions directory
├── config/             # Configuration files
└── lib/                # Library functions directory
```

To enable the skill, rename `SKILL.md.example` to `SKILL.md` and complete the TODOs.

## Skill Commands

Metool provides commands for skill management:

```bash
# Create a new package (includes SKILL.md.example template)
mt package new <package-name> [directory]

# Validate package structure and SKILL.md
mt package validate <package-name|path>
```

## Documentation Strategy

- **README.md** - Human-facing: installation, usage examples, requirements
- **SKILL.md** - AI-facing: procedural knowledge, workflows, tool references
- **docs/** - Shared reference: detailed schemas, APIs, conventions

Avoid duplication between README.md and SKILL.md. Each should serve its audience.

## Writing Effective Skills

**Writing Style:** Use imperative/infinitive form (verb-first instructions), not second person. Write "To accomplish X, do Y" rather than "You should do X".

**Content Guidelines:**
- Focus on procedural knowledge that Claude cannot infer
- Reference package tools by their command names (they're in PATH after install)
- Point to docs/ files for detailed reference material
- Include concrete examples with realistic scenarios
- Keep SKILL.md under 5k words; move details to docs/

## Skill Installation

When a package with `SKILL.md` is installed via `mt package install`, metool automatically creates symlinks to make the skill available to Claude Code:

1. Package directory → `~/.metool/skills/<package-name>`
2. `~/.metool/skills/<package-name>` → `~/.claude/skills/<package-name>`

Claude Code discovers skills by scanning `~/.claude/skills/` for `SKILL.md` files.

## Understanding the Skill with Concrete Examples

To create an effective skill, clearly understand concrete examples of how the skill will be used. This understanding can come from either direct user examples or generated examples that are validated with user feedback.

For example, when building an image-editor skill, relevant questions include:

- "What functionality should the image-editor skill support? Editing, rotating, anything else?"
- "Can you give some examples of how this skill would be used?"
- "What would a user say that should trigger this skill?"

## Planning the Reusable Skill Contents

To turn concrete examples into an effective skill, analyze each example by:

1. Considering how to execute on the example from scratch
2. Identifying what scripts, docs, and assets would be helpful when executing these workflows repeatedly

Example: When building a `git-hygiene` metool package with skill to handle queries like "Show me pending commits across repos," the analysis shows:

1. Checking git status requires re-writing the same code each time
2. A `bin/git-status-summary` script would be helpful for the metool package
3. A `shell/aliases` file with common git shortcuts would enhance interactive workflow
4. The SKILL.md guides Claude on how to use these tools for efficient git workflows

## Iteration

After testing the skill, users may request improvements. Often this happens right after using the skill, with fresh context of how the skill performed.

**Iteration workflow:**
1. Use the skill on real tasks
2. Notice struggles or inefficiencies
3. Identify how SKILL.md or bundled resources should be updated
4. Implement changes and test again
