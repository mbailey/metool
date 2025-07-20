#!/usr/bin/env bats

# Test host_identity support in mt sync

load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  export MT_PKG_DIR="${TMPDIR}/.metool"
  export MT_GIT_PROTOCOL_DEFAULT="git"
  export MT_GIT_HOST_DEFAULT="github.com"
  export MT_GIT_USER_DEFAULT="mbailey"
  
  # Create working directory
  export WORK_DIR="${TMPDIR}/project"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Source required files
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/git.sh"
  source "${MT_ROOT}/lib/sync.sh"
}

teardown() {
  cd "${BATS_TEST_DIRNAME}"
  rm -rf "${TMPDIR}"
}

@test "_mt_parse_repos_file handles host_identity format" {
  cat > repos.txt << 'EOF'
github.com_mbailey:mbailey/keycutter
github.com_work:company/internal-tool    tools
gitlab.com_personal:user/project@v1.0    my-project    local
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  # Check output is TSV format
  [[ "${lines[0]}" =~ ^github.com_mbailey:mbailey/keycutter$'\t'shared$'\t'keycutter$ ]]
  [[ "${lines[1]}" =~ ^github.com_work:company/internal-tool$'\t'shared$'\t'tools$ ]]
  [[ "${lines[2]}" =~ ^gitlab.com_personal:user/project@v1.0$'\t'local$'\t'my-project$ ]]
}

@test "_mt_repo_url generates correct SSH URL for host_identity" {
  run _mt_repo_url "github.com_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "_mt_repo_url generates SSH URL for host_identity even with HTTPS default" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  
  # Host identities always use SSH regardless of protocol default
  run _mt_repo_url "github.com_work:company/tools"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_work:company/tools.git" ]
}

@test "_mt_repo_dir strips host_identity by default" {
  run _mt_repo_dir "github.com_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "${MT_GIT_BASE_DIR}/github.com/mbailey/keycutter" ]
}

@test "_mt_repo_dir includes host_identity when MT_GIT_INCLUDE_IDENTITY_IN_PATH=true" {
  export MT_GIT_INCLUDE_IDENTITY_IN_PATH=true
  run _mt_repo_dir "github.com_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "${MT_GIT_BASE_DIR}/github.com_mbailey/mbailey/keycutter" ]
}

@test "mt sync creates correct paths for host_identity repos" {
  cat > repos.txt << 'EOF'
github.com_mbailey:mbailey/test-repo
github.com_work:work/project
EOF

  # Mock git operations
  _mt_git_clone() {
    local url="$1"
    local path="$2"
    mkdir -p "${path}/.git"
    return 0
  }
  
  _mt_repo_available() {
    return 0
  }
  
  run _mt_sync_process_repos repos.txt "$(pwd)" 2>&1
  [ "$status" -eq 0 ]
  
  # Check symlinks created
  [ -L "test-repo" ]
  [ -L "project" ]
  
  # Check canonical paths strip identity by default
  [ -d "${MT_GIT_BASE_DIR}/github.com/mbailey/test-repo/.git" ]
  [ -d "${MT_GIT_BASE_DIR}/github.com/work/project/.git" ]
}

@test "host_identity repos use same path by default" {
  cat > repos.txt << 'EOF'
github.com_personal:acme/webapp    webapp-personal
EOF

  # Mock git operations
  _mt_git_clone() {
    local url="$1"
    local path="$2"
    mkdir -p "${path}/.git"
    # Store which identity was used
    echo "$url" > "${path}/.git/clone-url"
    return 0
  }
  
  _mt_repo_available() {
    return 0
  }
  
  run _mt_sync_process_repos repos.txt "$(pwd)" 2>&1
  [ "$status" -eq 0 ]
  
  # Check symlink created
  [ -L "webapp-personal" ]
  
  # Check it points to the standard location (identity stripped)
  local standard_path="${MT_GIT_BASE_DIR}/github.com/acme/webapp"
  
  [ -d "${standard_path}/.git" ]
  
  # Verify the clone URL has the identity
  grep -q "git@github.com_personal:acme/webapp" "${standard_path}/.git/clone-url"
}

@test "host_identity repos can use separate paths with MT_GIT_INCLUDE_IDENTITY_IN_PATH" {
  export MT_GIT_INCLUDE_IDENTITY_IN_PATH=true
  
  cat > repos.txt << 'EOF'
github.com_personal:acme/webapp    webapp-personal
github.com_work:acme/webapp         webapp-work
EOF

  # Mock git operations
  _mt_git_clone() {
    local url="$1"
    local path="$2"
    mkdir -p "${path}/.git"
    # Store which identity was used
    echo "$url" > "${path}/.git/clone-url"
    return 0
  }
  
  _mt_repo_available() {
    return 0
  }
  
  run _mt_sync_process_repos repos.txt "$(pwd)" 2>&1
  [ "$status" -eq 0 ]
  
  # Check both symlinks created with different names
  [ -L "webapp-personal" ]
  [ -L "webapp-work" ]
  
  # Check they point to different locations
  local personal_path="${MT_GIT_BASE_DIR}/github.com_personal/acme/webapp"
  local work_path="${MT_GIT_BASE_DIR}/github.com_work/acme/webapp"
  
  [ -d "${personal_path}/.git" ]
  [ -d "${work_path}/.git" ]
  
  # Verify different clone URLs were used
  grep -q "git@github.com_personal:acme/webapp" "${personal_path}/.git/clone-url"
  grep -q "git@github.com_work:acme/webapp" "${work_path}/.git/clone-url"
}

@test "mixed format repos work together" {
  cat > repos.txt << 'EOF'
mbailey/metool
github.com_mbailey:mbailey/keycutter
user/project@v1.0    my-project
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  # Check all formats parsed correctly
  [[ "${lines[0]}" =~ ^mbailey/metool$'\t'shared$'\t'metool$ ]]
  [[ "${lines[1]}" =~ ^github.com_mbailey:mbailey/keycutter$'\t'shared$'\t'keycutter$ ]]
  [[ "${lines[2]}" =~ ^user/project@v1.0$'\t'shared$'\t'my-project$ ]]
}

@test "integration test with real keycutter format" {
  # Create repos.txt with keycutter-style entries
  cat > repos.txt << 'EOF'
github.com_mbailey:mbailey/keycutter         keycutter-mbailey
github.com_work:company/keycutter             keycutter-work
github.com:standard/repo                      standard-repo
EOF

  # Mock git operations
  _mt_git_clone() {
    local url="$1"
    local path="$2"
    mkdir -p "${path}/.git"
    echo "$url" > "${path}/.git/remote-url"
    return 0
  }
  
  _mt_repo_available() {
    return 0
  }
  
  run _mt_sync_process_repos repos.txt "$(pwd)" 2>&1
  [ "$status" -eq 0 ]
  
  # Verify symlinks
  [ -L "keycutter-mbailey" ]
  [ -L "keycutter-work" ]
  [ -L "standard-repo" ]
  
  # Verify correct URLs were used for cloning (identity stripped from paths)
  grep -q "git@github.com_mbailey:mbailey/keycutter" \
    "${MT_GIT_BASE_DIR}/github.com/mbailey/keycutter/.git/remote-url"
  grep -q "git@github.com_work:company/keycutter" \
    "${MT_GIT_BASE_DIR}/github.com/company/keycutter/.git/remote-url"
  grep -q "git@github.com:standard/repo" \
    "${MT_GIT_BASE_DIR}/github.com/standard/repo/.git/remote-url"
}

@test "_identity shorthand parsing expands correctly" {
  cat > repos.txt << 'EOF'
_mbailey:mbailey/keycutter
_work:company/tools           company-tools
_personal:user/project@v1.0   my-project    local
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  # Check that _identity: expanded to github.com_identity:
  [[ "${lines[0]}" =~ ^github.com_mbailey:mbailey/keycutter$'\t'shared$'\t'keycutter$ ]]
  [[ "${lines[1]}" =~ ^github.com_work:company/tools$'\t'shared$'\t'company-tools$ ]]
  [[ "${lines[2]}" =~ ^github.com_personal:user/project@v1.0$'\t'local$'\t'my-project$ ]]
}

@test "_identity shorthand generates correct URLs" {
  run _mt_repo_url "_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
  
  run _mt_repo_url "_work:company/tools"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_work:company/tools.git" ]
}

@test "_identity shorthand creates correct paths" {
  run _mt_repo_dir "_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  # Identity should be stripped by default
  [ "$output" = "${MT_GIT_BASE_DIR}/github.com/mbailey/keycutter" ]
}

@test "_identity shorthand integration test" {
  cat > repos.txt << 'EOF'
_mbailey:mbailey/keycutter           keycutter-mb
_work:company/tools                   company-tools
EOF

  # Mock git operations
  _mt_git_clone() {
    local url="$1"
    local path="$2"
    mkdir -p "${path}/.git"
    echo "$url" > "${path}/.git/remote-url"
    return 0
  }
  
  _mt_repo_available() {
    return 0
  }
  
  run _mt_sync_process_repos repos.txt "$(pwd)" 2>&1
  [ "$status" -eq 0 ]
  
  # Verify symlinks
  [ -L "keycutter-mb" ]
  [ -L "company-tools" ]
  
  # Verify correct URLs and paths were used (identity stripped from paths)
  grep -q "git@github.com_mbailey:mbailey/keycutter" \
    "${MT_GIT_BASE_DIR}/github.com/mbailey/keycutter/.git/remote-url"
  grep -q "git@github.com_work:company/tools" \
    "${MT_GIT_BASE_DIR}/github.com/company/tools/.git/remote-url"
}

@test "_:owner/repo now auto-matches instead of rejecting" {
  cat > repos.txt << 'EOF'
_:mbailey/invalid-repo
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  # Should NOT output error message - _: is now valid for auto-matching
  [[ ! "$output" =~ "Invalid shorthand format" ]]
  # Should expand correctly
  [[ "$output" =~ "github.com_mbailey:mbailey/invalid-repo" ]]
}

@test "_:owner/repo auto-matches identity to owner" {
  run _mt_repo_url "_:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
  
  run _mt_repo_url "_:employer/tools"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_employer:employer/tools.git" ]
  
  run _mt_repo_url "_:acme/webapp"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_acme:acme/webapp.git" ]
}

@test "_:owner/repo creates correct paths" {
  run _mt_repo_dir "_:mbailey/keycutter"
  [ "$status" -eq 0 ]
  # Path should strip identity by default
  [ "$output" = "${MT_GIT_BASE_DIR}/github.com/mbailey/keycutter" ]
}

@test "_:owner/repo works in repos.txt parsing" {
  cat > repos.txt << 'EOF'
_:mbailey/notes           notes-personal
_:employer/infrastructure  infra-work
_:acme/webapp@v2.0       webapp
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  # Parse output into lines
  IFS=$'\n' read -d '' -r -a lines <<< "$output" || true
  [ "${#lines[@]}" -eq 3 ]
  
  # Check expansions
  [[ "${lines[0]}" =~ ^github.com_mbailey:mbailey/notes$'\t'shared$'\t'notes-personal$ ]]
  [[ "${lines[1]}" =~ ^github.com_employer:employer/infrastructure$'\t'shared$'\t'infra-work$ ]]
  [[ "${lines[2]}" =~ ^github.com_acme:acme/webapp@v2.0$'\t'shared$'\t'webapp$ ]]
}

@test "_: without owner/repo format is rejected" {
  run _mt_repo_url "_:invalid-format"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid repository format for auto-identity" ]]
  [[ "$output" =~ "Expected 'owner/repo' format" ]]
}