#!/usr/bin/env bats

# Source the helper script
# shellcheck source=test_helper.bash
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  
  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Source the required files
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/sync.sh"
  source "${MT_ROOT}/lib/git.sh"
  
  # Mock log functions
  _mt_info() {
    echo "INFO: $*"
  }
  
  _mt_error() {
    echo "ERROR: $*" >&2
    return 1
  }
  
  _mt_warning() {
    echo "WARNING: $*"
  }
  
  _mt_debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo "DEBUG: $*"
  }
}

teardown() {
  # Clean up temporary directory
  rm -rf "${TMPDIR}"
}

@test "mt git add shows help" {
  run _mt_git_add --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: mt git add" ]]
  [[ "$output" =~ "Add a repository to the nearest .repos.txt file" ]]
}

@test "mt git add fails when not in git repo" {
  run _mt_git_add
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not in a git repository" ]]
}

@test "mt git add creates .repos.txt when it doesn't exist" {
  # Create a test git repo
  git init
  git remote add origin git@github.com:test/repo.git
  
  # Simulate choosing option 1 (current directory) and confirming addition
  echo -e "1\ny" | _mt_git_add
  local result=$?
  [ "$result" -eq 0 ]
  
  # Check that .repos.txt was created
  [ -f ".repos.txt" ]
  
  # Check that entry was added
  grep -q "test/repo" .repos.txt
}

@test "mt git add with --yes flag adds without prompting" {
  # Create a test git repo
  git init
  git remote add origin git@github.com:example/project.git
  
  # Create .repos.txt first
  touch .repos.txt
  
  # Add with --yes flag
  run _mt_git_add --yes
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Added to .repos.txt: example/project" ]]
  
  # Verify entry was added
  grep -q "example/project" .repos.txt
}

@test "mt git add detects duplicates" {
  # Create a test git repo
  git init
  git remote add origin git@github.com:duplicate/test.git
  
  # Create .repos.txt with existing entry
  echo "duplicate/test" > .repos.txt
  
  # Try to add duplicate
  run _mt_git_add --yes
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Entry already exists" ]]
  
  # Verify only one entry exists
  [ "$(grep -c "duplicate/test" .repos.txt)" -eq 1 ]
}

@test "mt git add with custom alias" {
  # Create a test git repo
  git init
  git remote add origin git@github.com:custom/alias.git
  
  # Create .repos.txt
  touch .repos.txt
  
  # Add with custom alias
  MT_GIT_AUTO_ADD=true run _mt_git_add custom/alias my-alias
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Added to .repos.txt: custom/alias as my-alias" ]]
  
  # Verify entry with alias was added
  grep -q "custom/alias	my-alias" .repos.txt
}

@test "mt git add handles SSH identity format" {
  # Create a test git repo
  git init
  git remote add origin git@github.com_work:company/project.git
  
  # Create .repos.txt
  touch .repos.txt
  
  # Add repository
  MT_GIT_AUTO_ADD=true run _mt_git_add
  [ "$status" -eq 0 ]
  
  # Should store in special format
  grep -q "github.com_work:company/project" .repos.txt
}

@test "mt git add searches up directory tree within git repo" {
  # Create a git repo with nested directories
  git init
  git remote add origin git@github.com:parent/repo.git
  
  # Create .repos.txt at git root
  touch .repos.txt
  
  # Create nested directory structure
  mkdir -p deeply/nested/child
  
  # Change to nested directory and run git add
  cd deeply/nested/child
  
  # Add should find .repos.txt at git root
  export MT_GIT_AUTO_ADD=true
  _mt_git_add
  local result=$?
  
  # Check that command succeeded
  [ "$result" -eq 0 ]
  
  # Go back to root to check the file
  cd ../../..
  
  # Check that entry was added to root's file
  grep -q "parent/repo" .repos.txt
}

@test "mt git add respects MT_GIT_AUTO_ADD environment variable" {
  # Create a test git repo
  git init
  git remote add origin git@github.com:env/test.git
  touch .repos.txt
  
  # With MT_GIT_AUTO_ADD=true, should add without prompting
  MT_GIT_AUTO_ADD=true run _mt_git_add
  [ "$status" -eq 0 ]
  grep -q "env/test" .repos.txt
}

@test "mt git add handles repositories without .git extension" {
  # Create a test git repo
  git init
  git remote add origin git@github.com:no/extension
  touch .repos.txt
  
  # Add repository
  MT_GIT_AUTO_ADD=true run _mt_git_add
  [ "$status" -eq 0 ]
  
  # Should be stored without .git extension
  grep -q "no/extension" .repos.txt
  ! grep -q "no/extension.git" .repos.txt
}