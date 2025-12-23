# Docs Folder Structure

Standard layout for the `/docs/` directory in metool and metool packages.

## Two Approaches

There are two valid ways to organize documentation:

1. **Category-based** (Diátaxis) - Separate directories for reference, guides, etc.
2. **Topic-based** - Files grouped by topic with suffixes like `-guide`, `-reference`

See [docs-structure-concepts.md](docs-structure-concepts.md) for when to use each.

**For metool itself**: Use category-based (the full structure below).

**For metool packages**: Use topic-based (simpler, see below).

## Full Structure (Category-Based)

For larger projects like metool core:

```
docs/
├── README.md           # Entry point
├── conventions/        # Standards and best practices
│   ├── README.md
│   └── *.md
├── reference/          # Command reference, API docs
│   ├── README.md
│   └── commands/
├── guides/             # How-to tutorials
│   ├── README.md
│   └── *.md
├── templates/          # Reusable templates
│   └── */
└── development/        # Contributor docs
    ├── README.md
    └── *.md
```

### Directory Purposes

| Directory | Content | Audience |
|-----------|---------|----------|
| conventions/ | Rules, patterns, standards | Contributors |
| reference/ | Commands, API, config options | All users |
| guides/ | Step-by-step tutorials | Users learning |
| templates/ | Copy-and-modify starting points | Package authors |
| development/ | Architecture, releases, internals | Maintainers |

## Simple Structure (Topic-Based)

For metool packages and smaller projects:

```
docs/
├── README.md              # Overview and navigation
├── topic-guide.md         # How to do X
├── topic-reference.md     # Details about X
└── another-topic.md       # Single file if small
```

### File Suffixes

Use suffixes to indicate document type:

| Suffix | Purpose | Example |
|--------|---------|---------|
| `-guide` | How to accomplish a goal | `authentication-guide.md` |
| `-reference` | Technical details, options | `cli-reference.md` |
| `-concepts` | Background, theory, "why" | `architecture-concepts.md` |

No suffix needed for:
- README.md files
- Single-topic files that are self-explanatory
- Files where the type is obvious from context

## File Naming

- Lowercase with hyphens: `getting-started.md`
- Be specific: `shell-scripting.md` not `scripting.md`
- Avoid abbreviations: `configuration.md` not `config.md`
- Group related: `testing-patterns.md`, `testing-bats.md`

## When to Create Subdirectories

Create a subdirectory when:
- 4+ related files exist
- Logical grouping is clear
- Different audiences need different content

Examples:
- `reference/commands/` - Many command docs
- `conventions/documentation/` - Multiple doc standards

## README.md in docs/

The top-level docs/README.md should:

1. List all major sections with links
2. Provide a reading order for newcomers
3. Describe what each section contains

Example:

```markdown
# Documentation

## For Users

- [Getting Started](guides/getting-started.md)
- [Command Reference](reference/commands/)

## For Contributors

- [Development Setup](development/setup.md)
- [Conventions](conventions/)
```

## Cross-Linking

Use relative links between docs:
- `[Shell Scripting](../conventions/shell-scripting.md)`
- `[mt cd command](../reference/commands/cd.md)`

Avoid:
- Absolute paths
- Bare URLs to other files
- "Click here" link text

## Maintenance

When adding content:
1. Check if it fits in existing files
2. Create new files only for distinct topics
3. Update parent README.md with links
4. Keep files focused on single topics

When removing content:
1. Check for incoming links
2. Update or redirect linking documents
3. Update parent README.md
