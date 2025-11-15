#!/usr/bin/env bats
# Tests for working set helper functions (MT-11)

load test_helper

setup() {
  # Create temporary test directory
  export TEST_DIR="${BATS_TMPDIR}/metool-test-$$"
  export MT_PKG_DIR="${TEST_DIR}/.metool"
  export MT_MODULES_DIR="${MT_PKG_DIR}/modules"
  export MT_PACKAGES_DIR="${MT_PKG_DIR}/packages"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."

  mkdir -p "${TEST_DIR}"
  mkdir -p "${MT_MODULES_DIR}"
  mkdir -p "${MT_PACKAGES_DIR}"

  # Source required libraries
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/working-set.sh"
}

teardown() {
  # Clean up test directory
  if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
}

# Module helper function tests

@test "working-set: _mt_module_path returns path for valid module" {
  # Create test module
  local module_dir="${TEST_DIR}/test-module"
  mkdir -p "${module_dir}"

  # Create symlink in modules working set
  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"

  # Test function - compare resolved paths
  result=$(_mt_module_path "test-module")
  expected=$(readlink -f "${module_dir}")
  [ "$result" = "$expected" ]
}

@test "working-set: _mt_module_path returns error for missing module" {
  run _mt_module_path "nonexistent"
  [ $status -ne 0 ]
}

@test "working-set: _mt_module_in_working_set returns true for existing module" {
  # Create test module
  local module_dir="${TEST_DIR}/test-module"
  mkdir -p "${module_dir}"
  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"

  # Test function
  _mt_module_in_working_set "test-module"
  [ $? -eq 0 ]
}

@test "working-set: _mt_module_in_working_set returns false for missing module" {
  run _mt_module_in_working_set "nonexistent"
  [ $status -ne 0 ]
}

@test "working-set: _mt_module_name_from_path returns correct name" {
  result=$(_mt_module_name_from_path "/some/path/test-module")
  [ "$result" = "test-module" ]
}

# Package helper function tests

@test "working-set: _mt_package_path returns path for valid package" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}"

  # Create symlink in packages working set
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function - compare resolved paths
  result=$(_mt_package_path "test-package")
  expected=$(readlink -f "${package_dir}")
  [ "$result" = "$expected" ]
}

@test "working-set: _mt_package_path returns error for missing package" {
  run _mt_package_path "nonexistent"
  [ $status -ne 0 ]
}

@test "working-set: _mt_package_in_working_set returns true for existing package" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function
  _mt_package_in_working_set "test-package"
  [ $? -eq 0 ]
}

@test "working-set: _mt_package_in_working_set returns false for missing package" {
  run _mt_package_in_working_set "nonexistent"
  [ $status -ne 0 ]
}

@test "working-set: _mt_package_is_installed detects installed package" {
  # Create test package with bin directory
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  echo "#!/bin/bash" > "${package_dir}/bin/test-cmd"

  # Add to working set
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Create installed symlink (simulate stow)
  mkdir -p "${MT_PKG_DIR}/bin"
  ln -s "${package_dir}/bin/test-cmd" "${MT_PKG_DIR}/bin/test-cmd"

  # Test function
  _mt_package_is_installed "test-package"
  [ $? -eq 0 ]
}

@test "working-set: _mt_package_is_installed returns false for non-installed package" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"

  # Add to working set but don't install
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function
  run _mt_package_is_installed "test-package"
  [ $status -ne 0 ]
}

@test "working-set: _mt_package_module_name extracts module from path" {
  # Create module and package structure
  local module_dir="${TEST_DIR}/modules/test-module"
  local package_dir="${module_dir}/test-package"
  mkdir -p "${package_dir}"

  # Create symlinks
  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function
  result=$(_mt_package_module_name "test-package")
  [ "$result" = "test-module" ]
}

@test "working-set: _mt_package_has_services detects systemd user services" {
  # Create package with systemd service
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/dot-config/systemd/user"
  touch "${package_dir}/config/dot-config/systemd/user/test.service"

  # Add to working set
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function
  _mt_package_has_services "test-package"
  [ $? -eq 0 ]
}

@test "working-set: _mt_package_has_services detects launchd services" {
  # Create package with launchd plist
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/macos"
  touch "${package_dir}/config/macos/com.test.plist"

  # Add to working set
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function
  _mt_package_has_services "test-package"
  [ $? -eq 0 ]
}

@test "working-set: _mt_package_has_services returns false for package without services" {
  # Create package without services
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"

  # Add to working set
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Test function
  run _mt_package_has_services "test-package"
  [ $status -ne 0 ]
}
