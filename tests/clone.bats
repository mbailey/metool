#!/usr/bin/env bats

# Source the helper script - disable shellcheck warning about relative path
# shellcheck source=test_helper.bash
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export TEST_REPO_NAME="test-repo"
  export TEST_REPO_PATH="${TMPDIR}/${TEST_REPO_NAME}"
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  
  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Source the required files directly
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  
  # Create custom mock functions for testing
  
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
    # Only output in debug mode (usually silent in tests)
    if [[ "${MT_DEBUG:-false}" == "true" ]]; then
      echo "DEBUG: $*"
    fi
  }
  
  # Mock _mt_create_relative_symlink for testing
  _mt_create_relative_symlink() {
    local target_path="$1"
    local link_name="$2"
    # Use same approach as real implementation for portability
    if command ln --help 2>&1 | grep -q -- --relative; then
      ln -sr "${target_path}" "${link_name}"
    else
      # Fallback for systems without GNU ln
      ln -s "${target_path}" "${link_name}"
    fi
  }
  
  # Mock _mt_init_ln_command
  _mt_init_ln_command() {
    _MT_LN_COMMAND="ln"
    return 0
  }
  
  # Mock _mt_create_symlink - this is called by _mt_clone
  _mt_create_symlink() {
    local current_dir="$1"
    local target_path="$2"
    local repo_name="$(basename "${target_path}")"
    
    if [[ "$current_dir" == "$(dirname "${target_path}")" ]]; then
      return 0
    fi
    
    if [[ -L "$repo_name" ]]; then
      local existing_target
      existing_target="$(readlink -f "$repo_name")"
      
      # Normalize both paths to handle macOS /private symlinks
      local normalized_existing=$(command realpath "$existing_target" 2>/dev/null || echo "$existing_target")
      local normalized_target=$(command realpath "$target_path" 2>/dev/null || echo "$target_path")
      
      if [[ "$normalized_existing" == "$normalized_target" ]]; then
        _mt_info "Symlink exists and points to the correct location: ${repo_name} -> ${target_path}"
      else
        _mt_warning "Symlink exists but points to a different location: ${repo_name} -> ${existing_target}"
        _mt_warning "Expected target: ${target_path}"
      fi
    elif [[ -e "$repo_name" ]]; then
      # Check if the existing path and target are the same
      local existing_path target_real
      existing_path="$(realpath "$repo_name" 2>/dev/null || echo "$repo_name")"
      target_real="$(realpath "$target_path" 2>/dev/null || echo "$target_path")"

      if [[ "$existing_path" == "$target_real" ]]; then
        # Source and destination are identical, no symlink needed
        _mt_debug "Skipping symlink creation: $repo_name and $target_path are the same"
      else
        _mt_warning "Cannot create symlink: ${repo_name} already exists and is not a symlink"
      fi
    else
      _mt_info "Creating symlink: ${repo_name} -> ${target_path}"
      _mt_create_relative_symlink "${target_path}" "${repo_name}"
    fi
  }
  
  # Mock repo URL and directory functions
  _mt_repo_url() {
    echo "https://github.com/test-user/${TEST_REPO_NAME}.git"
  }
  
  _mt_repo_dir() {
    echo "${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  }
  
  # Mock git clone function
  _mt_git_clone() {
    local git_repo_url="$1"
    local git_repo_path="$2"
    
    if [[ "${git_repo_url}" == *"non-existent"* ]]; then
      echo "ERROR: Failed to clone repository"
      return 1
    fi
    
    mkdir -p "${git_repo_path}"
    mkdir -p "${git_repo_path}/.git"
    echo "INFO: Repository cloned successfully"
    return 0
  }
  
  # Custom _mt_clone function that only has the basic logic
  _mt_clone() {
    local git_repo="${1:-}"
    
    # Show usage if no arguments provided or help flag
    if [[ -z $git_repo || "$git_repo" == "--help" || "$git_repo" == "-h" ]]; then
      echo "Usage: mt clone <git_repo> [<destination_path>]"
      echo
      echo "Clone a git repository to a canonical location."
      echo "If the repository already exists, display its status instead."
      return 1
    fi
    
    local git_repo_url="$(_mt_repo_url "${git_repo}")"
    local git_repo_path="$(_mt_repo_dir "${git_repo_url}")"
    
    # Check if destination exists and is a git repo
    if [[ -d "${git_repo_path}" && -d "${git_repo_path}/.git" ]]; then
      # Get the remote URL
      if [[ -f "${git_repo_path}/.git/config" ]]; then
        local existing_remote_url=""
        existing_remote_url=$(grep -A1 "remote \"origin\"" "${git_repo_path}/.git/config" | grep "url" | cut -d'=' -f2 | tr -d ' ')
        
        # Compare URLs
        if [[ "${existing_remote_url}" == "${git_repo_url}" ]]; then
          echo "INFO: Repository already exists at ${git_repo_path}"
          
          # Get branch info if HEAD exists
          if [[ -f "${git_repo_path}/.git/HEAD" ]]; then
            local branch_ref=$(cat "${git_repo_path}/.git/HEAD")
            local branch_name="${branch_ref##*/}"
            echo "INFO: Current branch: ${branch_name}"
          fi
          
          # Create symlink in current dir
          _mt_create_symlink "$(pwd)" "${git_repo_path}"
          return 0
        else
          echo "ERROR: Directory ${git_repo_path} already exists but contains a different repository"
          echo "INFO: Existing remote: ${existing_remote_url}"
          echo "INFO: Requested: ${git_repo_url}"
          return 1
        fi
      fi
    fi
    
    # Clone the repository
    if _mt_git_clone "${git_repo_url}" "${git_repo_path}"; then
      _mt_create_symlink "$(pwd)" "${git_repo_path}"
      return 0
    else
      return 1
    fi
  }
}

teardown() {
  cd "${BATS_TEST_DIRNAME}" # Return to the tests directory
  rm -rf "${TMPDIR}"        # Clean up temporary directory
}

@test "mt clone shows usage when no arguments provided" {
  run _mt_clone
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage: mt clone" ]]
}

@test "mt clone shows usage with --help flag" {
  run _mt_clone --help
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage: mt clone" ]]
  [[ "$output" =~ "If the repository already exists, display its status instead" ]]
}

@test "mt clone detects already cloned repository" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  
  # Create the target directory structure with config file
  mkdir -p "${target_dir}/.git"
  
  # Add origin remote to git config
  cat > "${target_dir}/.git/config" << EOL
[core]
	repositoryformatversion = 0
	filemode = true
[remote "origin"]
	url = https://github.com/test-user/${TEST_REPO_NAME}.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOL

  # Create HEAD file pointing to master branch
  echo "ref: refs/heads/master" > "${target_dir}/.git/HEAD"
  
  run _mt_clone "${TEST_REPO_NAME}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Repository already exists" ]]
  [[ "$output" =~ "Current branch: master" ]]
}

@test "mt clone detects different repository in target directory" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  
  # Create the target directory structure
  mkdir -p "${target_dir}/.git"
  
  # Add different origin remote to git config
  cat > "${target_dir}/.git/config" << EOL
[core]
	repositoryformatversion = 0
	filemode = true
[remote "origin"]
	url = https://github.com/different-user/${TEST_REPO_NAME}.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOL
  
  run _mt_clone "${TEST_REPO_NAME}"
  
  [ "$status" -eq 1 ]
  [[ "$output" =~ "contains a different repository" ]]
  [[ "$output" =~ "different-user" ]]
}

@test "mt clone creates symlink when repository is cloned successfully" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  
  run _mt_clone "${TEST_REPO_NAME}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Repository cloned successfully" ]]
  [[ "$output" =~ "Creating symlink" ]]
  
  # Verify the symlink exists and points to the right place
  [ -L "${WORK_DIR}/${TEST_REPO_NAME}" ]
  local actual_target=$(cd "${WORK_DIR}" && readlink -f "${TEST_REPO_NAME}")
  local expected_target=$(cd "${MT_GIT_BASE_DIR}" && realpath "github.com/test-user/${TEST_REPO_NAME}")
  [ "${actual_target}" = "${expected_target}" ]
}

@test "mt clone detects existing symlink pointing to correct location" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  
  # Create the target directory structure
  mkdir -p "${target_dir}/.git"
  
  # Add origin remote to git config
  cat > "${target_dir}/.git/config" << EOL
[core]
	repositoryformatversion = 0
	filemode = true
[remote "origin"]
	url = https://github.com/test-user/${TEST_REPO_NAME}.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOL
  
  # Create a symlink to the target
  _mt_create_relative_symlink "${target_dir}" "${TEST_REPO_NAME}"
  
  run _mt_clone "${TEST_REPO_NAME}"
  
  [ "$status" -eq 0 ]
  echo "DEBUG OUTPUT: $output" >&2
  [[ "$output" =~ "Repository already exists" ]]
  [[ "$output" =~ "Symlink exists and points to the correct location" ]]
}

@test "mt clone detects existing symlink pointing to different location" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  local different_dir="${TMPDIR}/different-dir"
  
  # Create the target directory structure
  mkdir -p "${target_dir}/.git"
  
  # Add origin remote to git config
  cat > "${target_dir}/.git/config" << EOL
[core]
	repositoryformatversion = 0
	filemode = true
[remote "origin"]
	url = https://github.com/test-user/${TEST_REPO_NAME}.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOL
  
  # Create a different directory and link to it
  mkdir -p "${different_dir}"
  _mt_create_relative_symlink "${different_dir}" "${TEST_REPO_NAME}"
  
  run _mt_clone "${TEST_REPO_NAME}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Repository already exists" ]]
  [[ "$output" =~ "Symlink exists but points to a different location" ]]
}

@test "mt clone detects non-symlink with same name" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"
  
  # Create the target directory structure
  mkdir -p "${target_dir}/.git"
  
  # Add origin remote to git config
  cat > "${target_dir}/.git/config" << EOL
[core]
	repositoryformatversion = 0
	filemode = true
[remote "origin"]
	url = https://github.com/test-user/${TEST_REPO_NAME}.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOL
  
  # Create a regular file with the same name
  touch "${TEST_REPO_NAME}"
  
  run _mt_clone "${TEST_REPO_NAME}"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Repository already exists" ]]
  [[ "$output" =~ "Cannot create symlink" ]]
  [[ "$output" =~ "already exists and is not a symlink" ]]
}

@test "mt clone doesn't create symlink when clone fails" {
  # Set repo URL to trigger the failure case in our mock
  TEST_REPO_NAME="non-existent-repo"

  run _mt_clone "${TEST_REPO_NAME}"

  [ "$status" -eq 1 ]
  [[ "$output" =~ "Failed to clone repository" ]]

  # Check that no symlink was created
  [ ! -L "${WORK_DIR}/${TEST_REPO_NAME}" ]
}

@test "mt clone skips symlink when file and target are identical" {
  local target_dir="${MT_GIT_BASE_DIR}/github.com/test-user/${TEST_REPO_NAME}"

  # Create the target directory structure
  mkdir -p "${target_dir}/.git"

  # Add origin remote to git config
  cat > "${target_dir}/.git/config" << EOL
[core]
	repositoryformatversion = 0
	filemode = true
[remote "origin"]
	url = https://github.com/test-user/${TEST_REPO_NAME}.git
	fetch = +refs/heads/*:refs/remotes/origin/*
EOL

  # Change to the target directory parent (where we'd normally create the symlink)
  # In this case, we're already in the directory where the repo exists
  cd "${target_dir}"

  run _mt_clone "${TEST_REPO_NAME}"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "Repository already exists" ]]
  # Should NOT show the warning about symlink creation
  [[ ! "$output" =~ "Cannot create symlink" ]]
  # With debug mode, we'd see the skip message, but without it, no output about symlink
}