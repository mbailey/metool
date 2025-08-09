# Documentation Organization

Guidelines for organizing and maintaining documentation files in the project.

## File Naming Conventions

- Use lowercase with hyphens: `error-handling.md`, not `ErrorHandling.md`
- Be specific: `function-naming.md` rather than `naming.md`
- Group related topics: `testing-patterns.md`, `testing-bats.md`

## Content Guidelines

### When to Create New Files

Split content into separate files when:
- A section exceeds ~50 lines
- The topic is self-contained
- Multiple subtopics exist (create a directory)
- Different audiences need different content

### Link Conventions

```markdown
# Good - descriptive link text
See [Function Naming Patterns](./function-naming.md) for details.

# Bad - vague link text
See [here](./function-naming.md) for more.
```

### File Headers

Each file should start with:
```markdown
# Clear Title

Brief description of what this document covers.

## When to Read This
- Specific scenarios when this is relevant
```

## Maintenance

### Adding Content
1. Check if it fits in existing files first
2. Create new files only for distinct topics
3. Update parent README.md with links
4. Keep files focused on single topics

### Removing Content
1. Check for incoming links before deleting
2. Redirect or update linking documents
3. Consider archiving vs deleting

## Examples

### Good Structure
```
conventions/
├── README.md           # Overview and common patterns
├── testing/           # Testing-related conventions
│   ├── README.md      # Testing overview
│   ├── bats.md        # BATS-specific patterns
│   └── examples/      # Example test files
└── naming.md          # Naming conventions
```

### Poor Structure
```
conventions/
├── everything.md      # 500+ line file
├── misc.md           # Grab bag of unrelated items
└── temp.md           # Unclear purpose
```

## Key Principles

1. **Discoverable** - Clear names and organization
2. **Focused** - One topic per file
3. **Linked** - Connected documentation
4. **Maintainable** - Easy to update and extend