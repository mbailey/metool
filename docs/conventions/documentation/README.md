# Documentation Conventions

Standards for documentation in metool and metool packages.

## Documentation Types

| Type | Location | Purpose |
|------|----------|---------|
| [Project README](#project-readme) | `/README.md` | Entry point, installation, overview |
| [Directory README](#directory-readme) | `*/README.md` | Folder contents and navigation |
| [Root files](#root-files) | Project root | AGENTS.md, SKILL.md, CHANGELOG.md, etc. |
| [Docs folder](#docs-folder) | `/docs/` | Detailed guides and references |
| [Command help](#command-help) | CLI `--help` | Usage, options, examples |
| [Code comments](#code-comments) | Source files | Function docs, inline notes |

## Project README

Root-level README.md serving as the main entry point:

```markdown
# Project Name

Brief description (1-2 sentences)

## Installation

Quick install steps

## Usage

Common examples

## Documentation

Link to docs/ for more
```

See [readme-guide.md](readme-guide.md) for full templates.

## Directory README

README.md files in subdirectories for progressive disclosure:

- List what the directory contains
- Link to files within the directory
- Provide brief context for each item
- Keep under 50 lines when possible

See [readme-guide.md](readme-guide.md) for the pattern.

## Root Files

Documentation files that live outside `docs/`:

- **AGENTS.md** - AI agent instructions (industry standard)
- **SKILL.md** - Claude Code skill definition
- **CONTRIBUTING.md** - Contribution guidelines
- **CHANGELOG.md** - Version history

See [root-documentation.md](root-documentation.md) for the complete list.

## Docs Folder

**For metool packages**: Use a flat docs/ directory with topic-based files. Add suffixes (`-guide`, `-reference`, `-concepts`) only when disambiguation helps.

```
docs/
├── README.md           # Optional overview
├── installation.md     # Single-topic file
├── advanced-guide.md   # How-to with suffix
└── commands/           # Command reference (matches bin/)
    ├── tool-name.md    # Matches bin/tool-name
    └── other-cmd.md
```

For command reference, create a `docs/commands/` directory with one file per command, named identically to the binary in `bin/`. This makes it easy to find documentation for any command.

**For metool core and large projects**: Use category-based subdirectories when documentation grows beyond 10-15 files:

```
docs/
├── reference/      # API docs, command reference
├── guides/         # How-to tutorials
├── templates/      # Reusable templates
└── development/    # Contributor docs
```

See [docs-structure.md](docs-structure.md) for details and [docs-structure-concepts.md](docs-structure-concepts.md) for background on when to use each approach.

## Command Help

CLI commands should provide `--help` output with:
- Usage syntax
- Option descriptions
- Common examples

Reference documentation lives in `docs/reference/commands/`.

See [command-usage.md](command-usage.md) for the template.

## Code Comments

Function and inline documentation:

```bash
# Brief description of function
# $1 - First argument
# Returns: Description of output
function_name() {
    # Explain complex logic inline
}
```

See [writing-style.md](writing-style.md) for conventions.

## Quick Reference

- **File naming**: lowercase-with-hyphens.md
- **File suffixes**: `-guide`, `-reference`, `-concepts`
- **Headers**: ATX-style (`#`, `##`, `###`)
- **Code blocks**: Always specify language
- **Voice**: Active, present tense
- **Length**: Keep files focused; split at ~50 lines

## Detailed Guides

- [readme-guide.md](readme-guide.md) - Project and directory README templates
- [root-documentation.md](root-documentation.md) - Files outside docs/
- [docs-structure.md](docs-structure.md) - Standard docs folder layout
- [docs-structure-concepts.md](docs-structure-concepts.md) - Diátaxis vs topic-based
- [command-usage.md](command-usage.md) - CLI documentation conventions
- [writing-style.md](writing-style.md) - Markdown, tone, formatting
