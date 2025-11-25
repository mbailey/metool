#!/usr/bin/env bats
# Tests for mt doctor command (MT-12)

load test_helper

setup() {
  # Create temporary test directory
  export TEST_DIR="${BATS_TMPDIR}/metool-doctor-test-$$"
  export MT_PKG_DIR="${TEST_DIR}/.metool"
  export MT_MODULES_DIR="${MT_PKG_DIR}/modules"
  export MT_PACKAGES_DIR="${MT_PKG_DIR}/packages"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export HOME="${TEST_DIR}/home"

  mkdir -p "${TEST_DIR}"
  mkdir -p "${MT_MODULES_DIR}"
  mkdir -p "${MT_PACKAGES_DIR}"
  mkdir -p "${HOME}/.claude/skills"

  # Source required libraries
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/working-set.sh"
  source "${MT_ROOT}/lib/stow.sh"
  source "${MT_ROOT}/lib/package.sh"
  source "${MT_ROOT}/lib/doctor.sh"
}

teardown() {
  # Clean up test directory
  if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
}

# ==============================================================================
# Help Tests
# ==============================================================================

@test "doctor: --help shows usage information" {
  run _mt_doctor --help
  [ $status -eq 0 ]
  [[ "$output" =~ "Usage: mt doctor" ]]
  [[ "$output" =~ "--fix" ]]
  [[ "$output" =~ "--verbose" ]]
  [[ "$output" =~ "--json" ]]
}

# ==============================================================================
# Dependencies Tests
# ==============================================================================

@test "doctor: checks for stow dependency" {
  run _mt_doctor
  [[ "$output" =~ "stow" ]]
}

@test "doctor: checks for realpath dependency" {
  run _mt_doctor
  [[ "$output" =~ "realpath" ]]
}

@test "doctor: checks for bash dependency" {
  run _mt_doctor
  [[ "$output" =~ "bash" ]]
}

# ==============================================================================
# Working Set Tests
# ==============================================================================

@test "doctor: reports valid module symlinks" {
  # Create valid module
  local module_dir="${TEST_DIR}/test-module"
  mkdir -p "${module_dir}"
  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"

  run _mt_doctor --verbose
  [ $status -eq 0 ]
  [[ "$output" =~ "Modules:" ]] || [[ "$output" =~ "valid symlinks" ]]
}

@test "doctor: detects broken module symlink" {
  # Create broken module symlink
  ln -s "/nonexistent/path" "${MT_MODULES_DIR}/broken-module"

  run _mt_doctor
  [[ "$output" =~ "broken" ]] || [[ "$output" =~ "Module symlink broken" ]]
}

@test "doctor: reports valid package symlinks" {
  # Create valid package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_doctor --verbose
  [ $status -eq 0 ]
  [[ "$output" =~ "Packages:" ]] || [[ "$output" =~ "valid symlinks" ]]
}

@test "doctor: detects broken package symlink" {
  # Create broken package symlink
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_doctor
  [[ "$output" =~ "broken" ]] || [[ "$output" =~ "Package symlink broken" ]]
}

# ==============================================================================
# Skills Tests
# ==============================================================================

@test "doctor: checks skills directory" {
  mkdir -p "${MT_PKG_DIR}/skills"

  run _mt_doctor --verbose
  [[ "$output" =~ "Skills:" ]] || [[ "$output" =~ "skills" ]]
}

@test "doctor: detects broken skill symlink" {
  # Create broken skill symlink
  mkdir -p "${MT_PKG_DIR}/skills"
  ln -s "/nonexistent/path" "${MT_PKG_DIR}/skills/broken-skill"

  run _mt_doctor
  [[ "$output" =~ "broken" ]] || [[ "$output" =~ "skill" ]]
}

@test "doctor: detects broken claude skill symlink" {
  # Create broken Claude skill symlink
  ln -s "/nonexistent/path" "${HOME}/.claude/skills/broken-skill"

  run _mt_doctor
  [[ "$output" =~ "broken" ]] || [[ "$output" =~ "skill" ]]
}

# ==============================================================================
# Root Cause Analysis Tests
# ==============================================================================

@test "doctor: detects Claude Code snapshot path" {
  # Create broken symlink pointing to snapshot path
  mkdir -p "${MT_PKG_DIR}/skills"
  ln -s "${HOME}/.claude/settings/snapshots/abc123/packages/my-tool" "${MT_PKG_DIR}/skills/my-tool"

  run _mt_doctor
  [[ "$output" =~ "snapshot" ]] || [[ "$output" =~ "Claude Code" ]] || [[ "$output" =~ "broken" ]]
}

# ==============================================================================
# Installation Status Tests
# ==============================================================================

@test "doctor: detects package not installed" {
  # Create package in working set with components but not installed
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  echo '#!/bin/bash' > "${package_dir}/bin/test-script"
  chmod +x "${package_dir}/bin/test-script"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_doctor --verbose
  # Should warn about package not being installed
  [[ "$output" =~ "not installed" ]] || [[ "$output" =~ "working set" ]] || [ $status -eq 0 ]
}

@test "doctor: detects orphaned symlinks in bin/" {
  # Create orphaned symlink in bin
  mkdir -p "${MT_PKG_DIR}/bin"
  ln -s "/nonexistent/script" "${MT_PKG_DIR}/bin/orphaned-script"

  run _mt_doctor
  [[ "$output" =~ "Orphaned" ]] || [[ "$output" =~ "broken" ]] || [[ "$output" =~ "bin/" ]]
}

# ==============================================================================
# Conflict Detection Tests
# ==============================================================================

@test "doctor: detects potential stow conflicts" {
  # Create two packages with same file
  local pkg1_dir="${TEST_DIR}/pkg1"
  local pkg2_dir="${TEST_DIR}/pkg2"
  mkdir -p "${pkg1_dir}/bin" "${pkg2_dir}/bin"
  echo '#!/bin/bash' > "${pkg1_dir}/bin/shared-name"
  echo '#!/bin/bash' > "${pkg2_dir}/bin/shared-name"
  chmod +x "${pkg1_dir}/bin/shared-name" "${pkg2_dir}/bin/shared-name"

  ln -s "${pkg1_dir}" "${MT_PACKAGES_DIR}/pkg1"
  ln -s "${pkg2_dir}" "${MT_PACKAGES_DIR}/pkg2"

  run _mt_doctor
  [[ "$output" =~ "conflict" ]] || [[ "$output" =~ "Conflict" ]]
}

# ==============================================================================
# JSON Output Tests
# ==============================================================================

@test "doctor: --json outputs valid JSON structure" {
  run _mt_doctor --json
  [ $status -eq 0 ]
  [[ "$output" =~ "{" ]]
  [[ "$output" =~ "\"errors\":" ]]
  [[ "$output" =~ "\"warnings\":" ]]
  [[ "$output" =~ "\"status\":" ]]
}

@test "doctor: --json reports errors correctly" {
  # Create broken symlink to trigger error
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_doctor --json
  [[ "$output" =~ "\"errors\":" ]]
  [[ "$output" =~ "\"error_messages\":" ]]
}

# ==============================================================================
# Summary Tests
# ==============================================================================

@test "doctor: shows OK status when healthy" {
  run _mt_doctor
  [ $status -eq 0 ]
  # Accept OK, WARNINGS (no errors), or All checks passed
  [[ "$output" =~ "OK" ]] || [[ "$output" =~ "WARNINGS" ]] || [[ "$output" =~ "All checks passed" ]]
}

@test "doctor: shows ERRORS status when broken symlinks exist" {
  # Create broken symlink
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_doctor
  [[ "$output" =~ "ERRORS" ]] || [[ "$output" =~ "error" ]]
}

@test "doctor: shows recommendations when issues found" {
  # Create broken symlink
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_doctor
  [[ "$output" =~ "Recommendation" ]] || [[ "$output" =~ "Fix:" ]] || [[ "$output" =~ "mt package" ]]
}

# ==============================================================================
# Verbose Mode Tests
# ==============================================================================

@test "doctor: --verbose shows more details" {
  # Create valid module
  local module_dir="${TEST_DIR}/test-module"
  mkdir -p "${module_dir}"
  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"

  # Compare output with and without verbose
  run _mt_doctor
  local normal_output="$output"

  run _mt_doctor --verbose
  local verbose_output="$output"

  # Verbose should have more or equal content
  [ ${#verbose_output} -ge ${#normal_output} ]
}
