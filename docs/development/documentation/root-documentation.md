# Root Documentation Files

Documentation files that live outside the `docs/` directory.

## Overview

All detailed documentation belongs in `docs/`. However, certain standard files live at the project root or in subdirectories. This file defines the complete list of allowed documentation files outside `docs/`.

## Required Files

| File | Location | Description |
|------|----------|-------------|
| README.md | Project root | Main entry point, overview, quick start |

## Optional Standard Files

### AI Agent Files

| File | Location | Description |
|------|----------|-------------|
| AGENTS.md | Project root | AI agent instructions (industry standard) |
| SKILL.md | Project root | Claude Code skill definition (makes package a skill) |
| CLAUDE.md | Project root | Claude-specific instructions (reference AGENTS.md) |

**AGENTS.md** is the emerging industry standard for AI coding assistants, supported by OpenAI Codex, Google Jules, Cursor, and others. Use it for project context, build steps, conventions, and boundaries.

**SKILL.md** serves a different purpose - it makes a metool package discoverable as a Claude Code skill. It defines what the skill does and when to invoke it.

**CLAUDE.md** is for Claude-specific instructions. Typically it should reference AGENTS.md and add any Claude-only configuration.

### Project Files

| File | Location | Description |
|------|----------|-------------|
| CONTRIBUTING.md | Project root | Contribution guidelines |
| CHANGELOG.md | Project root | Version history |
| LICENSE | Project root | License text (typically no extension) |

## Directory READMEs

| File | Location | Description |
|------|----------|-------------|
| README.md | Any directory | Navigation and context for directory contents |

Directory READMEs serve progressive disclosure - they help readers understand what's in a directory and link to contents.

## Validation

To check for documentation files that don't match this convention:

```bash
# Find .md files outside docs/ that aren't on the allowed list
find . -name "*.md" -not -path "./docs/*" \
  | grep -v -E "(README|AGENTS|SKILL|CLAUDE|CONTRIBUTING|CHANGELOG)\.md$"
```

Any files found should either:
1. Move to `docs/`
2. Be added to this list (update the convention)

## Notes

- Prefer AGENTS.md for AI agent instructions (cross-tool compatible)
- Use SKILL.md to make a package a Claude Code skill
- CLAUDE.md can reference AGENTS.md for shared instructions
- LICENSE typically has no `.md` extension
- All other documentation content belongs in `docs/`

## See Also

- [AGENTS.md Standard](https://agents.md/) - Industry standard for AI coding agents
