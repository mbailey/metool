# README Guide

Templates and conventions for project and directory README files.

## Project README

The root-level README.md serves as the main entry point for humans and AI agents.

### Template

```markdown
# Project Name

Brief description of what this project does (1-2 sentences).

## Installation

\`\`\`bash
# Installation command
\`\`\`

## Quick Start

\`\`\`bash
# Most common usage example
\`\`\`

## Features

- Feature one
- Feature two
- Feature three

## Documentation

For detailed documentation, see [docs/](docs/).

- [Getting Started](docs/guides/getting-started.md)
- [Command Reference](docs/reference/commands/)
- [Contributing](CONTRIBUTING.md)

## Requirements

- Requirement 1
- Requirement 2

## License

[License type]
```

### Key Sections

| Section | Required | Purpose |
|---------|----------|---------|
| Title & Description | Yes | What it is, one glance |
| Installation | Yes | How to get it |
| Quick Start | Recommended | Fastest path to value |
| Features | Optional | What it does |
| Documentation | Recommended | Where to learn more |
| Requirements | When needed | Prerequisites |
| License | Recommended | Legal |

### Best Practices

- Keep under 100 lines when possible
- Lead with value: what does this do for me?
- Show, don't just tell: include runnable examples
- Link to docs/ for detailed information
- Update when major features change

## Directory README

README.md files in subdirectories provide progressive disclosure.

### Template

```markdown
# Directory Name

Brief description of what this directory contains.

## Contents

- [file-one.md](file-one.md) - Description of file one
- [file-two.md](file-two.md) - Description of file two
- [subdirectory/](subdirectory/) - Description of subdirectory

## Overview

Optional 2-3 sentence overview if the contents list isn't self-explanatory.

## See Also

- [Related directory](../related/) - How it relates
```

### Key Principles

1. **List contents first** - What's here?
2. **Brief descriptions** - One line per item
3. **Link everything** - Make it navigable
4. **Keep it short** - Under 50 lines ideal
5. **Update on changes** - Add/remove links as files change

### When to Add a Directory README

Add a README.md when:
- Directory has 3+ files
- Contents aren't obvious from names
- Navigation would help readers
- Providing context adds value

Skip if:
- Single file directory
- File names are self-explanatory
- Directory is transient/build output

## Package README

Metool packages require specific documentation.

### Template

```markdown
# Package Name

Brief description of what this package provides.

## Installation

\`\`\`bash
mt package add module/package-name
mt package install package-name
\`\`\`

## Components

- `bin/tool-name` - What the tool does
- `shell/functions` - Shell functions provided
- `config/dot-file` - Configuration installed

## Usage

### Command Line

\`\`\`bash
tool-name [options] <args>
\`\`\`

### Shell Functions

\`\`\`bash
function_name arg1 arg2
\`\`\`

## Configuration

Configuration file: `~/.config/package-name/config.yml`

\`\`\`yaml
option: value
\`\`\`

## Requirements

- bash 4.0+
- Other dependencies

## See Also

- [Related package](../related/) - How they work together
```

### Required Sections for Packages

1. **Title and description** - What it does
2. **Installation** - The two-step add + install
3. **Components** - What gets installed
4. **Usage** - How to use it
5. **Requirements** - Dependencies if any

## Examples

### Good Project README

```markdown
# metool

Package management for shell environments using GNU Stow.

## Installation

\`\`\`bash
git clone https://github.com/mbailey/metool ~/.metool
~/.metool/bin/mt bootstrap
\`\`\`

## Quick Start

\`\`\`bash
# Add and install a package
mt package add dev/git-tools
mt package install git-tools

# List installed packages
mt package list
\`\`\`

## Documentation

See [docs/](docs/) for guides and reference.
```

### Good Directory README

```markdown
# Conventions

Coding conventions and best practices for metool development.

## Contents

- [shell-scripting.md](shell-scripting.md) - Bash coding standards
- [testing.md](testing.md) - How to write tests
- [documentation/](documentation/) - Documentation standards
- [package-structure.md](package-structure.md) - Package layout
```
