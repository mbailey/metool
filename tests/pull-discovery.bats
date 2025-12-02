#!/usr/bin/env bats

# Test mt git pull manifest discovery functionality (replaces sync-discovery tests)

# shellcheck source=test_helper.bash
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_PKG_DIR="${TMPDIR}/.metool"
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"

  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"

  # Source the required files directly
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/git/manifest.sh"
  source "${MT_ROOT}/lib/git/common.sh"
  source "${MT_ROOT}/lib/git/pull.sh"

  # Mock log functions to simplify output
  _mt_log() {
    local level="$1"
    shift
    echo "${level}: $*"
  }

  _mt_info() {
    echo "INFO: $*"
  }

  _mt_error() {
    echo "ERROR: $*"
    return 1
  }

  _mt_warning() {
    echo "WARNING: $*"
  }

  _mt_debug() {
    echo "DEBUG: $*"
  }
}

teardown() {
  cd "${BATS_TEST_DIRNAME}" # Return to the tests directory
  rm -rf "${TMPDIR}"        # Clean up temporary directory
}

# Test file discovery functionality

@test "_mt_git_manifest_find should find .repos.txt in current directory" {
  echo "test-repo" > .repos.txt

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.repos.txt" ]]
}

@test "_mt_git_manifest_find should find repos.txt in current directory" {
  echo "test-repo" > repos.txt

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/repos.txt" ]]
}

@test "_mt_git_manifest_find should prefer .repos.txt over repos.txt" {
  echo "hidden-repo" > .repos.txt
  echo "visible-repo" > repos.txt

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.repos.txt" ]]
}

@test "_mt_git_manifest_find should return error when no file found" {
  run _mt_git_manifest_find
  [ "$status" -eq 1 ]
  [ "$output" = "" ]
}

@test "_mt_git_manifest_find should use specific filename when provided" {
  echo "custom-repo" > custom.txt

  run _mt_git_manifest_find "$(pwd)" "custom.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/custom.txt" ]]
}

@test "_mt_git_manifest_find should honor MT_PULL_FILE environment variable" {
  echo "env-repo" > env-repos.txt
  export MT_PULL_FILE="env-repos.txt"

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/env-repos.txt" ]]

  unset MT_PULL_FILE
}

@test "_mt_git_manifest_find should honor legacy MT_SYNC_FILE for backwards compat" {
  echo "env-repo" > env-repos.txt
  export MT_SYNC_FILE="env-repos.txt"

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/env-repos.txt" ]]

  unset MT_SYNC_FILE
}

@test "_mt_git_manifest_find should search up directory tree in git repo" {
  # Create a git repository
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create .repos.txt in root
  echo "root-repo" > .repos.txt
  git add .repos.txt
  git commit --quiet -m "Add repos file"

  # Create subdirectory and test from there
  mkdir -p src/components
  cd src/components

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/.repos.txt" ]]
  # Should find the root .repos.txt file
  [[ "$(cat "${output}")" == "root-repo" ]]
}

@test "_mt_git_manifest_find should stop at git repository root" {
  # Create outer directory with repos file
  cd "${TMPDIR}"
  echo "outer-repo" > .repos.txt

  # Create inner git repository
  mkdir inner-project
  cd inner-project
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create subdirectory in git repo
  mkdir src
  cd src

  # Should not find the outer .repos.txt because it's outside git repo
  run _mt_git_manifest_find
  [ "$status" -eq 1 ]
}

@test "_mt_git_manifest_find should find repos.txt in subdirectory of git repo" {
  # Create a git repository
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create repos.txt in a subdirectory
  mkdir -p frontend
  echo "frontend-repo" > frontend/repos.txt
  git add frontend/repos.txt
  git commit --quiet -m "Add frontend repos file"

  # Create deeper subdirectory and test from there
  mkdir -p frontend/src/components
  cd frontend/src/components

  run _mt_git_manifest_find
  [ "$status" -eq 0 ]
  [[ "$output" == *"/frontend/repos.txt" ]]
  [[ "$(cat "${output}")" == "frontend-repo" ]]
}

@test "_mt_git_manifest_find should only check current directory outside git repo" {
  # Ensure we're not in a git repo
  cd "${TMPDIR}/work"

  # Create parent directory with repos file
  cd ..
  echo "parent-repo" > .repos.txt

  # Go back to subdirectory
  cd work

  # Should not find parent .repos.txt because we're not in git repo
  run _mt_git_manifest_find
  [ "$status" -eq 1 ]
}

@test "_mt_git_manifest_find should work with directory argument" {
  mkdir -p testdir
  echo "dir-repo" > testdir/.repos.txt

  run _mt_git_manifest_find "testdir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/testdir/.repos.txt" ]]
}

@test "_mt_git_manifest_parse_args should use discovery for no arguments" {
  echo "mbailey/mt-public" > .repos.txt

  run _mt_git_manifest_parse_args
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "REPOS_FILE=.*/.repos.txt"
  echo "$output" | grep -q "WORK_DIR="
}

@test "_mt_git_manifest_parse_args should find repos in directory argument" {
  mkdir -p external
  echo "vendor/ui-lib" > external/.repos.txt

  run _mt_git_manifest_parse_args "external"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "REPOS_FILE=.*/external/.repos.txt"
  echo "$output" | grep -q "WORK_DIR=.*/external"
}

@test "_mt_git_manifest_parse_args should error when no repos file found" {
  # No repos file exists
  run _mt_git_manifest_parse_args
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "ERROR: No repos.txt or .repos.txt found"
}

@test "_mt_git_manifest_parse_args should handle explicit file argument" {
  echo "explicit-repo" > my-repos.txt

  run _mt_git_manifest_parse_args "my-repos.txt"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "REPOS_FILE=.*/my-repos.txt"
}

@test "_mt_git_manifest_parse_args should error for missing explicit file" {
  run _mt_git_manifest_parse_args "nonexistent.txt"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "ERROR: Path not found: nonexistent.txt"
}

@test "_mt_git_manifest_parse_args should error for directory with no repos file" {
  mkdir -p empty-dir

  run _mt_git_manifest_parse_args "empty-dir"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "ERROR: No repos.txt or .repos.txt found in directory: empty-dir"
}

@test "_mt_git_manifest_parse_args should handle --file option" {
  echo "custom-repo" > custom-file.txt

  run _mt_git_manifest_parse_args --file custom-file.txt
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "REPOS_FILE=.*/custom-file.txt"
}

@test "_mt_git_manifest_parse_args should error for missing --file" {
  run _mt_git_manifest_parse_args --file nonexistent.txt
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "ERROR: Specified repos file not found: nonexistent.txt"
}
