#!/usr/bin/env bats

# Source the helper script
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export HOME="${TMPDIR}/home"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  
  # Create test directories
  mkdir -p "${TMPDIR}/test-dir1"
  mkdir -p "${TMPDIR}/test-dir2"
  mkdir -p "${TMPDIR}/test-dir3"
  
  # Create a test symlink directory
  mkdir -p "${TMPDIR}/real-dir"
  ln -sf "${TMPDIR}/real-dir" "${TMPDIR}/symlink-dir"
  
  # Create working directory
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Save original PATH
  export ORIGINAL_PATH="$PATH"
  
  # Mock required functions
  _mt_error() { echo "ERROR: $*" >&2; }
  _mt_debug() { echo "DEBUG: $*"; }
  
  # Source the path functions library directly
  source "${MT_ROOT}/lib/path.sh"
}

teardown() {
  cd "${BATS_TEST_DIRNAME}" # Return to the tests directory
  PATH="$ORIGINAL_PATH"     # Restore original PATH
  rm -rf "${TMPDIR}"        # Clean up temporary directory
}

@test "_mt_path_prepend adds a single directory to PATH" {
  local dir="${TMPDIR}/test-dir1"
  
  # Ensure the directory is not already in PATH
  [[ ":$PATH:" != *":$dir:"* ]]
  
  # Prepend the directory to PATH
  _mt_path_prepend "$dir"
  
  # Check if the directory is at the beginning of PATH
  [[ "$PATH" == "$dir"* ]]
}

@test "_mt_path_prepend adds multiple directories to PATH in order" {
  local dir1="${TMPDIR}/test-dir1"
  local dir2="${TMPDIR}/test-dir2"
  local dir3="${TMPDIR}/test-dir3"
  
  # Prepend multiple directories to PATH
  _mt_path_prepend "$dir1" "$dir2" "$dir3"
  
  # Check if the directories are at the beginning of PATH in the correct order
  [[ "$PATH" == "$dir1:$dir2:$dir3"* ]]
}

@test "_mt_path_prepend removes existing directory and adds it to the beginning" {
  local dir="${TMPDIR}/test-dir1"
  
  # Add the directory to the end of PATH first
  export PATH="$PATH:$dir"
  
  # Check that the directory is initially at the end
  [[ "$PATH" == *"$dir" ]]
  
  # Prepend the directory
  _mt_path_prepend "$dir"
  
  # Check that the directory is now at the beginning and doesn't appear twice
  [[ "$PATH" == "$dir"* ]]
  [[ $(echo "$PATH" | tr ':' '\n' | grep -c "^$dir$") -eq 1 ]]
}

@test "_mt_path_prepend skips non-existent directories" {
  local dir="${TMPDIR}/nonexistent-dir"
  local original_path="$PATH"
  
  # Try to prepend a non-existent directory
  run _mt_path_prepend "$dir"
  
  # Check that PATH remains unchanged
  [ "$PATH" = "$original_path" ]
  [[ "$output" =~ "DEBUG: Directory does not exist" ]]
}

@test "_mt_path_prepend preserves symlinks and doesn't resolve them" {
  local symlink_dir="${TMPDIR}/symlink-dir"
  local real_dir="${TMPDIR}/real-dir"
  
  # Prepend the symlink directory
  _mt_path_prepend "$symlink_dir"
  
  # Check that the symlink path (not the real path) is in PATH
  [[ "$PATH" == "$symlink_dir"* ]]
  [[ "$PATH" != "$real_dir"* ]]
}

@test "_mt_path_append adds a single directory to PATH" {
  local dir="${TMPDIR}/test-dir1"
  
  # Ensure the directory is not already in PATH
  [[ ":$PATH:" != *":$dir:"* ]]
  
  # Append the directory to PATH
  _mt_path_append "$dir"
  
  # Check if the directory is at the end of PATH
  [[ "$PATH" == *"$dir" ]]
}

@test "_mt_path_append adds multiple directories to PATH in order" {
  local dir1="${TMPDIR}/test-dir1"
  local dir2="${TMPDIR}/test-dir2"
  local dir3="${TMPDIR}/test-dir3"
  
  # Append multiple directories to PATH
  _mt_path_append "$dir1" "$dir2" "$dir3"
  
  # Check if the directories are at the end of PATH in the correct order
  [[ "$PATH" == *"$dir1:$dir2:$dir3" ]]
}

@test "_mt_path_append removes existing directory and adds it to the end" {
  local dir="${TMPDIR}/test-dir1"
  
  # Add the directory to the beginning of PATH first
  export PATH="$dir:$PATH"
  
  # Check that the directory is initially at the beginning
  [[ "$PATH" == "$dir"* ]]
  
  # Append the directory
  _mt_path_append "$dir"
  
  # Check that the directory is now at the end and doesn't appear twice
  [[ "$PATH" == *"$dir" ]]
  [[ $(echo "$PATH" | tr ':' '\n' | grep -c "^$dir$") -eq 1 ]]
}

@test "_mt_path_append skips non-existent directories" {
  local dir="${TMPDIR}/nonexistent-dir"
  local original_path="$PATH"
  
  # Try to append a non-existent directory
  run _mt_path_append "$dir"
  
  # Check that PATH remains unchanged
  [ "$PATH" = "$original_path" ]
  [[ "$output" =~ "DEBUG: Directory does not exist" ]]
}

@test "_mt_path_append preserves symlinks and doesn't resolve them" {
  local symlink_dir="${TMPDIR}/symlink-dir"
  local real_dir="${TMPDIR}/real-dir"
  
  # Append the symlink directory
  _mt_path_append "$symlink_dir"
  
  # Check that the symlink path (not the real path) is in PATH
  [[ "$PATH" == *"$symlink_dir" ]]
  [[ "$PATH" != *"$real_dir" ]]
}

@test "_mt_path_rm removes a single directory from PATH" {
  local dir="${TMPDIR}/test-dir1"
  
  # Add the directory to PATH first
  export PATH="$dir:$PATH"
  
  # Check that the directory is initially in PATH
  [[ ":$PATH:" == *":$dir:"* ]]
  
  # Remove the directory
  _mt_path_rm "$dir"
  
  # Check that the directory is no longer in PATH
  [[ ":$PATH:" != *":$dir:"* ]]
}

@test "_mt_path_rm removes multiple directories from PATH" {
  local dir1="${TMPDIR}/test-dir1"
  local dir2="${TMPDIR}/test-dir2"
  local dir3="${TMPDIR}/test-dir3"
  
  # Add the directories to PATH first
  export PATH="$dir1:$dir2:$dir3:$PATH"
  
  # Check that the directories are initially in PATH
  [[ ":$PATH:" == *":$dir1:"* ]]
  [[ ":$PATH:" == *":$dir2:"* ]]
  [[ ":$PATH:" == *":$dir3:"* ]]
  
  # Remove the directories
  _mt_path_rm "$dir1" "$dir2" "$dir3"
  
  # Check that the directories are no longer in PATH
  [[ ":$PATH:" != *":$dir1:"* ]]
  [[ ":$PATH:" != *":$dir2:"* ]]
  [[ ":$PATH:" != *":$dir3:"* ]]
}

@test "_mt_path_rm skips non-existent directories" {
  local dir="${TMPDIR}/nonexistent-dir"
  local original_path="$PATH"
  
  # Try to remove a non-existent directory
  run _mt_path_rm "$dir"
  
  # Check that PATH remains unchanged
  [ "$PATH" = "$original_path" ]
  [[ "$output" =~ "DEBUG: Directory does not exist" ]]
}

@test "_mt_path_rm handles directories that are not in PATH" {
  local dir="${TMPDIR}/test-dir1"
  local original_path="$PATH"
  
  # Ensure the directory is not already in PATH
  [[ ":$PATH:" != *":$dir:"* ]]
  
  # Try to remove the directory
  run _mt_path_rm "$dir"
  
  # Check that PATH remains unchanged
  [ "$PATH" = "$original_path" ]
  [[ "$output" =~ "DEBUG: Not in PATH" ]]
}

@test "_mt_path_prepend and _mt_path_append work with both aliases" {
  local dir1="${TMPDIR}/test-dir1"
  local dir2="${TMPDIR}/test-dir2"
  
  # Use the aliases
  mt_path_prepend "$dir1"
  mt_path_append "$dir2"
  
  # Check that the directories are in PATH
  [[ "$PATH" == "$dir1"* ]]
  [[ "$PATH" == *"$dir2" ]]
}

@test "Path functions work together for complex PATH manipulation" {
  local dir1="${TMPDIR}/test-dir1"
  local dir2="${TMPDIR}/test-dir2"
  local dir3="${TMPDIR}/test-dir3"
  
  # Start with a clean PATH
  export PATH="${ORIGINAL_PATH}"
  
  # Add dir1 and dir2 to the beginning
  _mt_path_prepend "$dir1" "$dir2"
  
  # Add dir3 to the end
  _mt_path_append "$dir3"
  
  # Check initial state
  [[ "$PATH" == "$dir1:$dir2"* ]]
  [[ "$PATH" == *"$dir3" ]]
  
  # Move dir1 to the end
  _mt_path_rm "$dir1"
  _mt_path_append "$dir1"
  
  # Check that dir1 moved from beginning to end
  [[ "$PATH" == "$dir2"* ]]
  [[ "$PATH" == *"$dir1" ]]
  
  # Ensure dir3 is still at the end (before dir1 now)
  [[ "$PATH" == *"$dir3:$dir1" ]]
}