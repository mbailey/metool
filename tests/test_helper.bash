#!/usr/bin/env bash
# Test helper functions for bats tests

# Skip a test unless certain commands are available
require_command() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || {
      skip "Command '$cmd' is required but not found"
    }
  done
}

# Make assertions on file existence, permissions, etc.
assert_file_exists() {
  [ -e "$1" ] || { echo "File '$1' does not exist"; return 1; }
}

assert_file_not_exists() {
  [ ! -e "$1" ] || { echo "File '$1' exists but should not"; return 1; }
}

assert_dir_exists() {
  [ -d "$1" ] || { echo "Directory '$1' does not exist"; return 1; }
}

assert_symlink_to() {
  local link="$1"
  local target="$2"
  
  [ -L "$link" ] || { echo "'$link' is not a symbolic link"; return 1; }
  
  local actual_target
  actual_target=$(readlink -f "$link")
  
  [ "$actual_target" = "$target" ] || {
    echo "Symlink '$link' points to '$actual_target', expected '$target'"
    return 1
  }
}

# Capture the output of a command into a variable
# Usage: output=$(run_command ls -la)
run_command() {
  "$@"
}

# Utility function to create a test git repository
create_test_repo() {
  local repo_path="$1"
  local remote_url="$2"
  
  mkdir -p "$repo_path"
  (
    cd "$repo_path"
    git init > /dev/null 2>&1
    git config user.name "Test User" > /dev/null 2>&1
    git config user.email "test@example.com" > /dev/null 2>&1
    echo "# Test Repository" > README.md
    git add README.md > /dev/null 2>&1
    git commit -m "Initial commit" > /dev/null 2>&1
    
    if [ -n "$remote_url" ]; then
      git remote add origin "$remote_url" > /dev/null 2>&1
    fi
  )
}

# Create a file with uncommitted changes in a repository
create_uncommitted_changes() {
  local repo_path="$1"
  
  (
    cd "$repo_path"
    echo "Uncommitted change" > uncommitted.txt
  )
}

# Create a file, commit it, and optionally push
create_committed_change() {
  local repo_path="$1"
  local push="${2:-false}"
  
  (
    cd "$repo_path"
    echo "Committed change" > committed.txt
    git add committed.txt > /dev/null 2>&1
    git commit -m "Add committed change" > /dev/null 2>&1
    
    if [ "$push" = "true" ]; then
      git push origin master > /dev/null 2>&1
    fi
  )
}