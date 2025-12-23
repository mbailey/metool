# Writing Style

Markdown formatting, tone, and style conventions for documentation.

## Markdown Standards

### Headers

Use ATX-style headers with proper hierarchy:

```markdown
# Document Title

## Major Section

### Subsection

#### Sub-subsection (use sparingly)
```

Rules:
- One `#` per document
- Don't skip levels (`#` then `###`)
- Blank line before and after headers

### Code Blocks

Always specify the language:

````markdown
```bash
mt install package-name
```

```python
def example():
    pass
```

```yaml
key: value
```
````

For inline code, use single backticks: `mt install`

### Lists

Consistent markers, proper nesting:

```markdown
- First item
- Second item
  - Nested item
  - Another nested item
- Third item

1. Numbered item
2. Another numbered item
   - Can mix bullets in numbered lists
3. Final numbered item
```

### Tables

Use for structured data:

```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Data     | Data     | Data     |
```

Align columns for readability in source.

### Links

Descriptive link text:

```markdown
# Good
See [Shell Scripting Conventions](shell-scripting.md) for details.

# Bad
Click [here](shell-scripting.md) for more.
```

Use relative paths for internal links.

## Tone and Voice

### Active Voice

Write in active voice:

```markdown
# Good
The command creates a symlink.
Run the script to start.

# Avoid
A symlink is created by the command.
The script should be run to start.
```

### Present Tense

Use present tense:

```markdown
# Good
Returns the path to the module.
The function accepts two arguments.

# Avoid
Will return the path to the module.
The function accepted two arguments.
```

### Imperative for Instructions

Use imperative form for steps:

```markdown
# Good
1. Install the package.
2. Edit the configuration.
3. Restart the service.

# Avoid
1. You should install the package.
2. The configuration should be edited.
```

### Be Concise

- Short, clear sentences
- Remove unnecessary words
- Get to the point quickly

```markdown
# Good
Install with `mt install package`.

# Wordy
In order to install the package, you can use the mt install command.
```

## Special Sections

### Warnings

```markdown
> **Warning**: This command deletes files permanently.
```

### Notes

```markdown
> **Note**: Requires bash 4.0 or later.
```

### Tips

Use details for optional content:

```markdown
<details>
<summary>Tip: Speed up searches</summary>

Use specific patterns to reduce search time.

</details>
```

## Code Comments

### Function Documentation

Document at the function definition:

```bash
# Get the path to a metool module
# $1 - Module name
# Returns: Path to module directory
# Example: path=$(get_module_path "public")
get_module_path() {
    local module="$1"
    # Implementation
}
```

### Inline Comments

Explain why, not what:

```bash
# Good: explains the reason
# Use read to handle paths with spaces correctly
read -r path <<< "$output"

# Bad: restates the obvious
# Read the path variable
read -r path <<< "$output"
```

## Examples

### Good Examples

- Show common use cases first
- Include expected output when helpful
- Explain what each example does

```markdown
```bash
# Install a package from the dev module
mt package add dev/git-tools
mt package install git-tools

# List installed packages
mt package list
# Output:
#   git-tools  /path/to/git-tools
#   tmux       /path/to/tmux
```
```

### Avoid

- `foo`, `bar`, `baz` unless truly generic
- Overly complex examples
- Hardcoded paths like `/home/user/`

## Consistency

### Terminology

Use consistent terms throughout:

| Use | Don't Use |
|-----|-----------|
| package | pkg, module (when meaning package) |
| directory | folder (except in GUI context) |
| run | execute |
| file | doc (when meaning file) |

### Formatting

| Element | Format |
|---------|--------|
| Commands | `backticks` |
| File paths | `backticks` |
| Placeholders | `<angle-brackets>` |
| Optional | `[square-brackets]` |
| Keys/buttons | **Bold** |

## File Organization

### When to Split

Create separate files when:
- Section exceeds ~50 lines
- Topic is self-contained
- Different audiences need different content
- Multiple subtopics exist

### File Headers

Start each file with:

```markdown
# Clear Title

Brief description of what this document covers.

## Contents or first section
```

### Line Length

- No hard limit, but prefer under 100 characters
- Break long lines in lists for readability
- Don't break code blocks artificially
