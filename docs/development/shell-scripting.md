# Shell Scripting Conventions

## Shebang

Always use `#!/usr/bin/env bash` for portability:

```bash
#!/usr/bin/env bash
```

## Function Naming

### Private Functions
Functions intended for internal use should start with underscore:

```bash
_mt_internal_function() {
  # Implementation
}
```

### Public Functions
Public functions that users might call directly:

```bash
mt_public_function() {
  # Implementation
}
```

## Variable Naming

### Global Variables
- Use UPPERCASE with underscores
- Prefix with MT_ for metool-specific globals

```bash
MT_ROOT="/path/to/metool"
MT_PKG_DIR="${HOME}/.metool"
```

### Local Variables
- Use lowercase with underscores
- Always declare with `local`

```bash
local file_path="/tmp/example"
local is_valid=false
```

## Error Handling

### Function Return Values
- Return 0 for success
- Return 1 (or other non-zero) for failure

```bash
_mt_example() {
  if [[ ! -f "$1" ]]; then
    echo "Error: File not found" >&2
    return 1
  fi
  return 0
}
```

### Error Messages
Always send error messages to stderr:

```bash
echo "Error: Something went wrong" >&2
```

## Quoting

### Always Quote Variables
Prevents word splitting and glob expansion:

```bash
# Good
if [[ -f "$file_path" ]]; then

# Bad
if [[ -f $file_path ]]; then
```

### Exception: Arithmetic Context
```bash
if (( $# > 0 )); then
```

## Testing

### Use Double Brackets
Prefer `[[ ]]` over `[ ]` for conditionals:

```bash
# Good
if [[ -n "$var" ]]; then

# Avoid
if [ -n "$var" ]; then
```

### File Tests
```bash
[[ -f "$file" ]]    # Regular file exists
[[ -d "$dir" ]]     # Directory exists
[[ -e "$path" ]]    # Path exists (file or directory)
[[ -L "$link" ]]    # Symbolic link exists
[[ -x "$exec" ]]    # File is executable
```

## Command Substitution

Use `$()` instead of backticks:

```bash
# Good
result=$(command)

# Avoid
result=`command`
```

## Loops

### Iterating Over Files
Use null-terminated strings for files with spaces:

```bash
while IFS= read -r -d '' file; do
  echo "Processing: $file"
done < <(find . -type f -print0)
```

### Array Iteration
```bash
for item in "${array[@]}"; do
  echo "$item"
done
```

## Functions

### Parameter Validation
Check parameters at the start:

```bash
_mt_example() {
  if (($# != 2)); then
    echo "Usage: _mt_example <arg1> <arg2>" >&2
    return 1
  fi
  
  local arg1="$1"
  local arg2="$2"
  # Rest of function
}
```

### Return vs Exit
- Use `return` in functions
- Use `exit` only in scripts (not functions)

## Debugging

### Debug Logging
Use the MT_LOG_LEVEL environment variable:

```bash
_mt_log DEBUG "Variable value: $var"
_mt_log INFO "Processing file: $file"
_mt_log ERROR "Failed to open file"
```

### Set Options
For debugging scripts:

```bash
set -x  # Print commands as executed
set -e  # Exit on error
set -u  # Error on undefined variables
set -o pipefail  # Pipe failures cause exit
```

## Portability

### Avoid Bash-specific Features When Possible
But since we use bash, these are acceptable:
- Arrays
- `[[ ]]` conditionals  
- `(( ))` arithmetic
- Process substitution `<()`

### Use Portable Commands
```bash
# Good - POSIX compliant
command -v git >/dev/null

# Avoid - bash specific
type -P git >/dev/null
```

### Handle Missing Commands
```bash
if ! command -v realpath >/dev/null; then
  echo "Error: realpath is required" >&2
  exit 1
fi
```