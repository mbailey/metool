# Testing Conventions

## Test Organization

### File Naming
Test files should match the feature being tested:
- `cd.bats` - Tests for mt cd command
- `edit.bats` - Tests for mt edit command
- `path.bats` - Tests for path manipulation functions

### Test Naming
Use descriptive test names that explain what is being tested:

```bash
@test "_mt_cd to function changes to function's source file directory" {
  # Test implementation
}

@test "_mt_cd with non-existent target fails with error" {
  # Test implementation
}
```

## Test Structure

### Setup and Teardown

```bash
setup() {
  # Create temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  
  # Set up test environment
  cd "$TMPDIR"
}

teardown() {
  # Clean up
  cd /
  rm -rf "$TMPDIR"
}
```

### Test Helpers

Load the test helper at the beginning:

```bash
#!/usr/bin/env bats

load test_helper
```

## Writing Tests

### Basic Test Structure

```bash
@test "description of what is being tested" {
  # Arrange - Set up test conditions
  local test_file="${TMPDIR}/test.txt"
  echo "content" > "$test_file"
  
  # Act - Run the command
  run mt_command "$test_file"
  
  # Assert - Check the results
  [ "$status" -eq 0 ]
  [[ "$output" =~ "expected output" ]]
}
```

### Using run Command

The `run` command captures output and exit status:

```bash
run _mt_cd nonexistent

# Check exit status
[ "$status" -eq 1 ]

# Check output
[ "$output" = "Error: 'nonexistent' not found" ]

# Check output with regex
[[ "$output" =~ "not found" ]]
```

### Assertions

```bash
# Status assertions
[ "$status" -eq 0 ]          # Command succeeded
[ "$status" -ne 0 ]          # Command failed

# Output assertions
[ "$output" = "exact text" ]  # Exact match
[[ "$output" =~ "pattern" ]]  # Regex match

# File assertions (from test_helper)
assert_file_exists "$file"
assert_file_not_exists "$file"
assert_dir_exists "$dir"
assert_symlink_to "$link" "$target"
```

## Mocking

### Mock Functions
Override functions for testing:

```bash
# Mock a function that would normally require network
_mt_check_remote() {
  echo "mocked response"
  return 0
}
```

### Mock Commands
Create mock executables:

```bash
cat > "${TMPDIR}/mock-git" << 'EOF'
#!/bin/bash
echo "mock git output"
EOF
chmod +x "${TMPDIR}/mock-git"
export PATH="${TMPDIR}:$PATH"
```

## Test Data

### Use Descriptive Names

```bash
local test_function_name="test_function"
local test_executable_name="test-executable"
local test_dir_with_spaces="dir with spaces"
```

### Create Realistic Test Data

```bash
# Create a function source file
cat > "${TMPDIR}/functions.sh" << 'EOF'
test_function() {
  echo "This is a test function"
}
EOF
source "${TMPDIR}/functions.sh"
```

## Edge Cases

Always test edge cases:

```bash
@test "handles empty input" {
  run _mt_command ""
  [ "$status" -eq 1 ]
}

@test "handles paths with spaces" {
  local path_with_spaces="/tmp/path with spaces"
  mkdir -p "$path_with_spaces"
  run _mt_command "$path_with_spaces"
  [ "$status" -eq 0 ]
}

@test "handles special characters" {
  local special_path="/tmp/test\$file"
  touch "$special_path"
  run _mt_command "$special_path"
  [ "$status" -eq 0 ]
}
```

## Performance

### Skip Slow Tests
Mark slow tests so they can be skipped:

```bash
@test "slow operation" {
  skip "Slow test - enable with SLOW_TESTS=1"
  # Slow test implementation
}
```

### Use Timeouts
Set timeouts for tests that might hang:

```bash
# In Makefile
BATS_TEST_TIMEOUT=30 bats tests/edit.bats
```

## Debugging Tests

### Debug Output
Use stderr for debug output:

```bash
@test "complex test" {
  echo "DEBUG: variable=$variable" >&2
  run _mt_command
  echo "DEBUG: status=$status" >&2
  echo "DEBUG: output=$output" >&2
  [ "$status" -eq 0 ]
}
```

### Run Single Test
Run specific tests for debugging:

```bash
bats tests/cd.bats --filter "specific test name"
```

## Best Practices

1. **Test One Thing** - Each test should verify one specific behavior
2. **Independent Tests** - Tests should not depend on each other
3. **Clean Environment** - Each test should start with a clean state
4. **Descriptive Failures** - Use assertions that provide clear error messages
5. **Fast Tests** - Keep tests fast by using minimal setup
6. **Realistic Tests** - Test real-world scenarios, not just happy paths