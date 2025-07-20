# Metool Tests

This directory contains tests for the Metool (`mt`) utility. The tests use the [Bats](https://github.com/bats-core/bats-core) testing framework for Bash scripts.

## Running Tests

To run all tests:

```bash
make test
```

To run a specific test file:

```bash
bats tests/clone.bats
```

## Test Files

- `clone.bats`: Tests for the `mt clone` command, which clones git repositories to canonical locations and creates symlinks
- `install.bats`: Tests for the `mt install` command, which installs packages by creating symlinks for bin/, config/, and shell/ directories

## Test Structure

Each test file follows this structure:

1. `setup()`: Prepares the test environment, creating temporary directories and mock functions
2. `teardown()`: Cleans up after each test
3. `@test` blocks: Individual test cases that exercise specific functionality

## Adding New Tests

When adding new tests:

1. Create a new `.bats` file in the tests directory
2. Update the Makefile to include your test in the test target
3. Follow the pattern in existing test files, using mock functions where appropriate

## Mocking Strategy

The tests use function overrides to replace system calls and other complex operations. This allows the tests to:

- Run without modifying the real system
- Isolate the behavior being tested
- Provide predictable test inputs and outputs

## Test Helpers

The `test_helper.bash` file provides common functions used across test files:

- Assertions for file existence and content
- Utility functions for creating test repositories
- Helper functions for common test operations