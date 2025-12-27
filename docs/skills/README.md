# Skills

Skills extend Claude Code's capabilities by providing specialized knowledge, workflows, and tools. Metool packages can include a `SKILL.md` file to enable AI assistance for the package's domain.

## Contents

- [creating.md](creating.md) - How to create a SKILL.md file
- [structure.md](structure.md) - SKILL.md format and frontmatter requirements
- [progressive-disclosure.md](progressive-disclosure.md) - Token-efficient skill design patterns

## What Skills Provide

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

## Quick Reference

### Adding a Skill to a Package

1. Create `SKILL.md` in the package root
2. Add required frontmatter (name, description)
3. Run `mt package install` to register the skill

### SKILL.md Template

```markdown
---
name: package-name
description: Brief explanation. This skill should be used when [scenarios].
---

# Package Name

## Overview
[What this skill enables]

## Workflows
[Step-by-step procedures with tool references]
```

### Skill Installation

When installed via `mt package install`, metool creates symlinks:
1. Package → `~/.metool/skills/<package-name>`
2. `~/.metool/skills/<package-name>` → `~/.claude/skills/<package-name>`

## See Also

- [docs/packages/README.md](../packages/README.md) - Package structure
- [docs/packages/structure.md](../packages/structure.md) - SKILL.md in package context
