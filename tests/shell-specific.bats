#!/usr/bin/env bats

# Test shell-specific file sourcing

load test_helper

# Helper function that mimics the mt sourcing logic
source_shell_files() {
  # Detect current shell
  local current_shell=""
  if [[ -n "${BASH_VERSION}" ]]; then
    current_shell="bash"
  elif [[ -n "${ZSH_VERSION}" ]]; then
    current_shell="zsh"
  fi

  # Source all files under MT_PKG_DIR/shell with shell-specific logic
  if [[ -d "${MT_PKG_DIR}/shell" ]]; then
    while IFS= read -r -d '' file; do
      # Check file extension for shell-specific sourcing
      local filename="$(basename "$file")"
      local ext=""
      if [[ "$filename" == *.* ]]; then
        ext="${filename##*.}"
      fi

      # Determine if file should be sourced
      local should_source=true

      case "$ext" in
        bash)
          if [[ "$current_shell" != "bash" ]]; then
            should_source=false
          fi
          ;;
        zsh)
          if [[ "$current_shell" != "zsh" ]]; then
            should_source=false
          fi
          ;;
        sh|"")
          should_source=true
          ;;
        *)
          should_source=true
          ;;
      esac

      if [[ "$should_source" == "true" ]]; then
        source "$file"
      fi
    done < <(command find -L "${MT_PKG_DIR}/shell" -type f -not -name ".*" -print0 | command sort -z)
  fi
}

setup() {
  export TMPDIR=$(mktemp -d)
  export MT_PKG_DIR="${TMPDIR}/.metool"

  # Create shell directory structure
  mkdir -p "${MT_PKG_DIR}/shell/test-pkg"

  # Create test files with different extensions
  echo "export TEST_ALL='loaded'" > "${MT_PKG_DIR}/shell/test-pkg/all"
  echo "export TEST_SH='loaded'" > "${MT_PKG_DIR}/shell/test-pkg/common.sh"
  echo "export TEST_BASH='loaded'" > "${MT_PKG_DIR}/shell/test-pkg/bash-only.bash"
  echo "export TEST_ZSH='loaded'" > "${MT_PKG_DIR}/shell/test-pkg/zsh-only.zsh"
}

teardown() {
  rm -rf "${TMPDIR}"
  unset TEST_ALL TEST_SH TEST_BASH TEST_ZSH
}

@test "files with no extension are sourced in bash" {
  export BASH_VERSION="5.0.0"
  unset ZSH_VERSION

  source_shell_files

  [[ "${TEST_ALL}" == "loaded" ]]
}

@test "files with .sh extension are sourced in bash" {
  export BASH_VERSION="5.0.0"
  unset ZSH_VERSION

  source_shell_files

  [[ "${TEST_SH}" == "loaded" ]]
}

@test "files with .bash extension are sourced in bash" {
  export BASH_VERSION="5.0.0"
  unset ZSH_VERSION

  source_shell_files

  [[ "${TEST_BASH}" == "loaded" ]]
}

@test "files with .zsh extension are NOT sourced in bash" {
  export BASH_VERSION="5.0.0"
  unset ZSH_VERSION

  source_shell_files

  [[ -z "${TEST_ZSH}" ]]
}

@test "files with no extension are sourced in zsh" {
  unset BASH_VERSION
  export ZSH_VERSION="5.8"

  source_shell_files

  [[ "${TEST_ALL}" == "loaded" ]]
}

@test "files with .sh extension are sourced in zsh" {
  unset BASH_VERSION
  export ZSH_VERSION="5.8"

  source_shell_files

  [[ "${TEST_SH}" == "loaded" ]]
}

@test "files with .zsh extension are sourced in zsh" {
  unset BASH_VERSION
  export ZSH_VERSION="5.8"

  source_shell_files

  [[ "${TEST_ZSH}" == "loaded" ]]
}

@test "files with .bash extension are NOT sourced in zsh" {
  unset BASH_VERSION
  export ZSH_VERSION="5.8"

  source_shell_files

  [[ -z "${TEST_BASH}" ]]
}

@test "backward compatibility - existing packages without extensions work" {
  export BASH_VERSION="5.0.0"

  echo "export TEST_LEGACY='works'" > "${MT_PKG_DIR}/shell/test-pkg/functions"

  source_shell_files

  [[ "${TEST_LEGACY}" == "works" ]]
}
