# Documentation Conventions

## File Structure

```
docs/
├── README.md                 # Main documentation entry point
├── conventions/             # Coding standards and practices
│   ├── README.md
│   ├── shell-scripting.md
│   ├── testing.md
│   └── documentation.md
├── reference/              # Command reference
│   └── commands/
│       ├── README.md
│       ├── cd.md
│       ├── edit.md
│       └── ...
└── guides/                 # How-to guides
    └── ...
```

## Markdown Standards

### Headers
Use ATX-style headers with proper hierarchy:

```markdown
# Main Title

## Section

### Subsection

#### Sub-subsection
```

### Code Blocks
Always specify the language for syntax highlighting:

````markdown
```bash
mt edit ~/.bashrc
```

```python
def example():
    pass
```
````

### Lists
Use consistent list markers:

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

## Command Documentation

Each command should have its own file in `docs/reference/commands/` with this structure:

```markdown
# mt <command>

Brief description of what the command does

## Usage

```bash
mt <command> [options] <arguments>
```

## Description

Detailed explanation of the command's purpose and behavior

## Options

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output

## Arguments

- `<argument>` - Description of the argument

## Examples

```bash
# Example 1 with description
mt command arg1

# Example 2 with description  
mt command --option arg2
```

## Environment Variables

- `MT_ROOT` - Description of how it affects the command
- `EDITOR` - Used for editing files

## Notes

Additional information, caveats, or tips

## See Also

- [mt other-command](other-command.md) - Related command
```

## Code Comments

### Function Documentation
Document functions at the definition:

```bash
# Get all metool modules with caching
# Returns: TSV list of module_name<tab>module_path
# Example: public<tab>/home/user/.metool-public
_mt_get_modules() {
  # Implementation
}
```

### Inline Comments
Explain complex logic:

```bash
# Use read to properly handle spaces in paths
read -r _ _ source_file <<< "$func_output"

# Check if array has elements (not if it's defined)
if ((${#funcinfo[@]} > 0)); then
```

## Examples

### Good Examples
- Show common use cases first
- Include output when helpful
- Explain what the example does

```markdown
```bash
# Change to the directory containing a function
mt cd _mt_sync
# Changes to: /home/user/metool/lib

# Edit a configuration file
mt edit ~/.bashrc
# Opens: ~/.bashrc in your $EDITOR
```
```

### Bad Examples
- Don't use foo/bar unless necessary
- Avoid overly complex examples
- Don't assume specific paths

## Writing Style

### Be Concise
- Use short, clear sentences
- Avoid unnecessary words
- Get to the point quickly

### Be Consistent
- Use the same terminology throughout
- Follow the same structure for similar content
- Maintain the same tone

### Use Active Voice
- "The command creates a file" ✓
- "A file is created by the command" ✗

### Present Tense
- "Returns the path" ✓
- "Will return the path" ✗
- "Returned the path" ✗

## Updating Documentation

When making changes:

1. **Update affected documentation** - If you change behavior, update docs
2. **Add examples** - Show new features with examples
3. **Update cross-references** - Ensure links still work
4. **Check for accuracy** - Test examples to ensure they work

## API Documentation

For functions meant to be used by others:

```bash
# Public: Get the absolute path to a metool module
#
# $1 - Module name
#
# Examples:
#
#   module_path=$(mt_get_module_path "public")
#   echo "$module_path"  # /home/user/.metool-public
#
# Returns: 
#   0 - Success, prints module path to stdout
#   1 - Module not found
mt_get_module_path() {
  # Implementation
}
```

## Special Sections

### Warnings
Use blockquotes for warnings:

```markdown
> **Warning**: This command modifies files in place. Make backups first.
```

### Notes
Use blockquotes for important notes:

```markdown
> **Note**: This feature requires bash 4.0 or later.
```

### Tips
Use details for optional tips:

```markdown
<details>
<summary>💡 Tip: Speed up searches</summary>

Use more specific patterns to reduce search time:
- `mt edit _mt_` finds functions starting with _mt_
- `mt edit config` might match many files

</details>
```