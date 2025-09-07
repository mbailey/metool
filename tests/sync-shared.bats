#!/usr/bin/env bats

# Source the helper script
# shellcheck source=test_helper.bash
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  export MT_PKG_DIR="${TMPDIR}/.metool"
  export MT_GIT_PROTOCOL_DEFAULT="https"
  export MT_GIT_HOST_DEFAULT="github.com"
  export MT_GIT_USER_DEFAULT="mbailey"
  
  # Create working and external directories
  export WORK_DIR="${TMPDIR}/project"
  mkdir -p "${WORK_DIR}/external"
  cd "${WORK_DIR}/external"
  
  # Source required files
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/git.sh"
  source "${MT_ROOT}/lib/sync.sh"
  
  # Mock _mt_git_clone to avoid actual git operations
  # This must be defined after sourcing to override the real function
  _mt_git_clone() {
    local url="$1"
    local path="$2"
    
    # Clean path by removing any trailing content after newlines
    path="${path%%$'\n'*}"
    
    # Output similar messages to the real function
    echo "[INFO] Mock clone called with:" >&2
    echo "  URL: $url" >&2
    echo "  Path: $path" >&2
    
    # Simulate successful clone with a proper git repo
    mkdir -p "${path}"
    cd "${path}"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    
    # Create some fake tags/branches for version tests
    git tag v1.0.0
    git branch main
    
    cd - > /dev/null
    
    echo "[INFO] Created mock git dir: ${path}/.git" >&2
    return 0
  }
  
  # Mock _mt_repo_available to avoid network checks
  _mt_repo_available() {
    # Always return success to avoid network calls
    return 0
  }
  
  # Mock _mt_repo_dir to ensure it returns clean paths
  _mt_repo_dir() {
    local repo_url="$1"
    # Extract repo name from URL and strip .git extension
    local repo_name="${repo_url##*/}"
    repo_name="${repo_name%.git}"
    local org_name="${repo_url%/*}"
    org_name="${org_name##*/}"
    
    # Return canonical path (ensure no newlines or extra whitespace)
    local clean_path="${MT_GIT_BASE_DIR}/github.com/${org_name}/${repo_name}"
    printf "%s" "$clean_path"
  }
  
  # Mock repository status check
  _mt_check_repo_status() {
    local repo_path="${1}"
    
    if [[ ! -d "${repo_path}/.git" ]]; then
      echo "not_cloned"
    elif [[ -f "${repo_path}/.update_available" ]]; then
      echo "behind"
    else
      echo "current"
    fi
  }
  
  # Mock repository update
  _mt_update_repo() {
    local repo_path="${1}"
    
    if [[ -f "${repo_path}/.update_available" ]]; then
      rm -f "${repo_path}/.update_available"
      echo "[INFO] Updated repository"
      return 0
    else
      echo "[INFO] Already up to date"
      return 0
    fi
  }
  
  # Wrapper to capture both stdout and stderr
  run_with_stderr() {
    "$@" 2>&1
  }
}

teardown() {
  cd "${BATS_TEST_DIRNAME}"
  rm -rf "${TMPDIR}"
}

# Test basic shared repository sync

@test "mt sync should clone missing shared repository" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Check output
  [[ "$output" =~ "Cloning:" ]] && [[ "$output" =~ "mbailey/mt-public" ]]
  [[ "$output" =~ "[INFO] Repository cloned successfully" ]]
  
  # Check symlink was created
  [ -L "mt-public" ]
  
  # Check canonical location exists
  local expected_path="${MT_GIT_BASE_DIR}/github.com/mbailey/mt-public"
  [ -d "${expected_path}/.git" ]
}

@test "mt sync should skip already cloned shared repository" {
  # Pre-create the repository with proper git init
  local repo_path="${MT_GIT_BASE_DIR}/github.com/mbailey/mt-public"
  mkdir -p "${repo_path}"
  cd "${repo_path}"
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit" --quiet
  cd - > /dev/null
  
  # Create symlink in working directory
  cd "${WORK_DIR}/external"
  ln -s "${repo_path}" "mt-public"
  
  cat > repos.txt << 'EOF'
mbailey/mt-public
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Debug output to see what we actually get
  echo "ACTUAL OUTPUT: $output" >&3
  
  # Should report as current (Status message goes to stderr which we captured)
  [[ "$output" =~ "current" ]]
  [[ ! "$output" =~ "Cloning:" ]]
}

@test "mt sync should update repository that is behind" {
  # Pre-create repository with update flag
  local repo_path="${MT_GIT_BASE_DIR}/github.com/mbailey/mt-public"
  mkdir -p "${repo_path}"
  cd "${repo_path}"
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit" --quiet
  touch .update_available
  cd - > /dev/null
  
  # Create symlink in working directory
  cd "${WORK_DIR}/external"
  ln -s "${repo_path}" "mt-public"
  
  cat > repos.txt << 'EOF'
mbailey/mt-public
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Should update
  [[ "$output" =~ "behind" ]]
  [[ "$output" =~ "Updated repository" ]]
  
  # Update flag should be removed
  [ ! -f "${repo_path}/.update_available" ]
}

@test "mt sync should handle custom target names" {
  cat > repos.txt << 'EOF'
mbailey/mt-public    public-tools
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Check custom symlink name
  [ -L "public-tools" ]
  [ ! -L "mt-public" ]
  
  # Should still clone to canonical location
  local expected_path="${MT_GIT_BASE_DIR}/github.com/mbailey/mt-public"
  [ -d "${expected_path}/.git" ]
}

@test "mt sync should handle multiple repositories" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
vendor/tools
internal/api-client    api
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Check all symlinks created
  [ -L "mt-public" ]
  [ -L "tools" ]
  [ -L "api" ]
  
  # Check all repos cloned
  [ -d "${MT_GIT_BASE_DIR}/github.com/mbailey/mt-public/.git" ]
  [ -d "${MT_GIT_BASE_DIR}/github.com/vendor/tools/.git" ]
  [ -d "${MT_GIT_BASE_DIR}/github.com/internal/api-client/.git" ]
}

@test "mt sync should handle version specifications for shared repos" {
  cat > repos.txt << 'EOF'
mbailey/mt-public@v1.0.0
vendor/tools@main
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Should still create symlinks to canonical locations
  [ -L "mt-public" ]
  [ -L "tools" ]
  
  # Should report version checkouts
  [[ "$output" =~ "[INFO] Checkout: v1.0.0" ]]
  [[ "$output" =~ "[INFO] Checkout: main" ]]
}

@test "mt sync should detect existing symlink conflicts" {
  # Create conflicting symlink
  ln -s "/some/other/path" "mt-public"
  
  cat > repos.txt << 'EOF'
mbailey/mt-public
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Should detect conflict
  [[ "$output" =~ "[INFO] Symlink conflict" ]]
}

@test "mt sync should produce TSV summary output" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
vendor/tools@v2.0    tools-v2
EOF

  # Pre-create one repo to test mixed status  
  local repo_path="${MT_GIT_BASE_DIR}/github.com/mbailey/mt-public"
  mkdir -p "${repo_path}"
  cd "${repo_path}"
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit" --quiet
  cd - > /dev/null
  
  # Create symlink in working directory
  cd "${WORK_DIR}/external"
  ln -s "${repo_path}" "mt-public"
  
  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Should have summary section
  [[ "$output" =~ "Sync Summary:" ]]
  [[ "$output" =~ "REPO" ]]
  [[ "$output" =~ "REF" ]]
  [[ "$output" =~ "STATUS" ]]
  [[ "$output" =~ "TARGET" ]]
  [[ "$output" =~ "STRATEGY" ]]
  
  # Check specific entries exist in output (column order: REPO | REF | STATUS | TARGET | STRATEGY)
  [[ "$output" =~ "mbailey/mt-public" ]]
  [[ "$output" =~ "master" ]]  # Now shows actual branch instead of "default"
  [[ "$output" =~ "mt-public" ]]
  [[ "$output" =~ "shared" ]]
  
  [[ "$output" =~ "vendor/tools@v2.0" ]]
  [[ "$output" =~ "v2.0" ]]
  [[ "$output" =~ "tools-v2" ]]
}

@test "mt sync should show actual ref and indicate mismatches" {
  # Create a repo with a specific branch checked out
  local repo_path="${MT_GIT_BASE_DIR}/github.com/mbailey/feature-test"
  mkdir -p "${repo_path}"
  cd "${repo_path}"
  git init --quiet
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "test" > README.md
  git add README.md
  git commit -m "Initial commit" --quiet
  git branch main  # Create main branch
  git checkout -b feature-branch --quiet
  cd - > /dev/null
  
  # Create symlink
  cd "${WORK_DIR}/external"
  ln -s "${repo_path}" "feature-test"
  
  # Spec expects main branch
  cat > repos.txt << 'EOF'
mbailey/feature-test@main
EOF

  run run_with_stderr _mt_sync_process_repos repos.txt "$(pwd)" "false"
  [ "$status" -eq 0 ]
  
  # Should show actual branch with expected in parentheses
  [[ "$output" =~ "feature-branch (expected: main)" ]]
}