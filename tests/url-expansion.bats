#!/usr/bin/env bats

# Source the helper script
load test_helper

setup() {
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  
  # Source required files
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/git.sh"
  
  # Set defaults for testing
  export MT_GIT_HOST_DEFAULT="github.com"
  export MT_GIT_USER_DEFAULT="mbailey"
  export MT_GIT_BASE_DIR="${HOME}/Code"
}

# HTTPS Format Tests
@test "HTTPS: mbailey/keycutter -> https://github.com/mbailey/keycutter.git" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  
  run _mt_repo_url "mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/mbailey/keycutter.git" ]
}

@test "HTTPS: github.com/mbailey/keycutter -> https://github.com/mbailey/keycutter.git" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  
  run _mt_repo_url "github.com/mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/mbailey/keycutter.git" ]
}

@test "HTTPS: https://github.com/mbailey/keycutter -> https://github.com/mbailey/keycutter.git" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  
  run _mt_repo_url "https://github.com/mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/mbailey/keycutter.git" ]
}

@test "HTTPS: https://github.com/mbailey/keycutter.git -> https://github.com/mbailey/keycutter.git (no double .git)" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  
  run _mt_repo_url "https://github.com/mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/mbailey/keycutter.git" ]
}

# SSH without Identity Tests (git protocol default)
@test "SSH: :mbailey/keycutter -> git@github.com:mbailey/keycutter.git" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url ":mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "SSH: github.com:mbailey/keycutter -> git@github.com:mbailey/keycutter.git" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "github.com:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "SSH: github.com:mbailey/keycutter.git -> git@github.com:mbailey/keycutter.git (no double .git)" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "github.com:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "SSH: git@github.com:mbailey/keycutter -> git@github.com:mbailey/keycutter.git" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "git@github.com:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "SSH: git@github.com:mbailey/keycutter.git -> git@github.com:mbailey/keycutter.git (no double .git)" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "git@github.com:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "SSH default: mbailey/keycutter -> git@github.com:mbailey/keycutter.git (git protocol default)" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

# SSH with Identity Tests
@test "SSH Identity: _mbailey:mbailey/keycutter -> git@github.com_mbailey:mbailey/keycutter.git" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "SSH Identity: _mbailey:mbailey/keycutter.git -> git@github.com_mbailey:mbailey/keycutter.git (no double .git)" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "_mbailey:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "SSH Identity: github.com_mbailey:mbailey/keycutter -> git@github.com_mbailey:mbailey/keycutter.git" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "github.com_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "SSH Identity: github.com_mbailey:mbailey/keycutter.git -> git@github.com_mbailey:mbailey/keycutter.git (no double .git)" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "github.com_mbailey:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "SSH Identity: git@github.com_mbailey:mbailey/keycutter -> git@github.com_mbailey:mbailey/keycutter.git" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "git@github.com_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "SSH Identity: git@github.com_mbailey:mbailey/keycutter.git -> git@github.com_mbailey:mbailey/keycutter.git (no double .git)" {
  unset MT_GIT_PROTOCOL_DEFAULT  # Use git default
  
  run _mt_repo_url "git@github.com_mbailey:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

# Test URL passthrough for already complete URLs
@test "Passthrough: full SSH URL with .git preserved" {
  run _mt_repo_url "git@gitlab.com:user/project.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@gitlab.com:user/project.git" ]
}

@test "Passthrough: full HTTPS URL with .git preserved" {
  run _mt_repo_url "https://gitlab.com/user/project.git"
  [ "$status" -eq 0 ]
  [ "$output" = "https://gitlab.com/user/project.git" ]
}

# Auto-matching Identity Tests

@test "Auto-match Identity: _:owner/repo -> git@github.com_owner:owner/repo.git" {
  run _mt_repo_url "_:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "Auto-match Identity: _:org/repo -> git@github.com_org:org/repo.git" {
  run _mt_repo_url "_:employer/infrastructure"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_employer:employer/infrastructure.git" ]
}

@test "Auto-match Identity: _:owner/repo.git -> git@github.com_owner:owner/repo.git (no double .git)" {
  run _mt_repo_url "_:acme/webapp.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_acme:acme/webapp.git" ]
}

@test "Auto-match Identity: invalid format rejected" {
  run _mt_repo_url "_:not-owner-repo-format"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid repository format" ]]
}