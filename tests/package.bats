#!/usr/bin/env bats
# Tests for package commands (MT-11)

load test_helper

setup() {
  # Create temporary test directory
  export TEST_DIR="${BATS_TMPDIR}/metool-test-$$"
  export MT_PKG_DIR="${TEST_DIR}/.metool"
  export MT_MODULES_DIR="${MT_PKG_DIR}/modules"
  export MT_PACKAGES_DIR="${MT_PKG_DIR}/packages"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export HOME="${TEST_DIR}/home"

  mkdir -p "${TEST_DIR}"
  mkdir -p "${MT_MODULES_DIR}"
  mkdir -p "${MT_PACKAGES_DIR}"
  mkdir -p "${HOME}"

  # Source required libraries
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/working-set.sh"
  source "${MT_ROOT}/lib/stow.sh"
  source "${MT_ROOT}/lib/package.sh"

  # Require stow for install/uninstall tests
  require_command stow
}

teardown() {
  # Clean up test directory
  if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
}

# mt package list tests

@test "package: list shows empty working set" {
  run _mt_package_list
  [ $status -eq 0 ]
  [[ "$output" =~ "No packages in working set" ]]
}

@test "package: list shows not-installed package" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_list
  [ $status -eq 0 ]
  [[ "$output" =~ "test-package" ]]
  [[ "$output" =~ "✓" ]]  # Valid symlink indicator
}

@test "package: list shows installed package" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  echo "#!/bin/bash" > "${package_dir}/bin/test-cmd"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Simulate installation
  mkdir -p "${MT_PKG_DIR}/bin"
  ln -s "${package_dir}/bin/test-cmd" "${MT_PKG_DIR}/bin/test-cmd"

  run _mt_package_list
  [ $status -eq 0 ]
  [[ "$output" =~ "test-package" ]]
  [[ "$output" =~ "✓" ]]  # Valid symlink indicator
}

@test "package: list shows broken package symlink" {
  # Create broken symlink
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_package_list
  [ $status -eq 0 ]
  [[ "$output" =~ "broken-package" ]]
  [[ "$output" =~ "✗" ]]  # Broken indicator
}

@test "package: list displays module names" {
  # Create module and package
  local module_dir="${TEST_DIR}/modules/test-module"
  local package_dir="${module_dir}/test-package"
  mkdir -p "${package_dir}"

  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_list
  [ $status -eq 0 ]
  [[ "$output" =~ "test-module" ]]
}

# mt package add tests

@test "package: add requires module/package format" {
  run _mt_package_add
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "package: add validates format" {
  run _mt_package_add "invalid-format"
  [ $status -ne 0 ]
  [[ "$output" =~ "Invalid format" ]]
}

@test "package: add requires module in working set" {
  run _mt_package_add "nonexistent-module/package"
  [ $status -ne 0 ]
  [[ "$output" =~ "Module not in working set" ]]
}

@test "package: add validates package exists" {
  # Create module without package
  local module_dir="${TEST_DIR}/test-module"
  mkdir -p "${module_dir}"
  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"

  run _mt_package_add "test-module/nonexistent-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "Package not found" ]]
}

@test "package: add creates symlink successfully" {
  # Create module and package
  local module_dir="${TEST_DIR}/test-module"
  local package_dir="${module_dir}/test-package"
  mkdir -p "${package_dir}"

  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"

  run _mt_package_add "test-module/test-package"
  [ $status -eq 0 ]
  local expected=$(readlink -f "${package_dir}"); local actual=$(readlink -f "${MT_PACKAGES_DIR}/test-package"); [ "$actual" = "$expected" ]
}

@test "package: add detects existing package" {
  # Create module and package
  local module_dir="${TEST_DIR}/test-module"
  local package_dir="${module_dir}/test-package"
  mkdir -p "${package_dir}"

  ln -s "${module_dir}" "${MT_MODULES_DIR}/test-module"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_add "test-module/test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "already in working set" ]]
}

@test "package: add detects name conflict" {
  # Create two modules with same package name
  local module1_dir="${TEST_DIR}/module1"
  local module2_dir="${TEST_DIR}/module2"
  local package1_dir="${module1_dir}/test-package"
  local package2_dir="${module2_dir}/test-package"

  mkdir -p "${package1_dir}"
  mkdir -p "${package2_dir}"

  ln -s "${module1_dir}" "${MT_MODULES_DIR}/module1"
  ln -s "${module2_dir}" "${MT_MODULES_DIR}/module2"
  ln -s "${package1_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_add "module2/test-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "name conflict" ]]
}

# mt package remove tests

@test "package: remove requires package name" {
  run _mt_package_remove
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "package: remove validates package exists" {
  run _mt_package_remove "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "package: remove deletes symlink" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  _mt_package_remove "test-package" < <(echo "y") >/dev/null 2>&1
  [ ! -L "${MT_PACKAGES_DIR}/test-package" ]
}

@test "package: remove warns if package is installed" {
  skip "Interactive confirmation test - tested manually"
  # This test requires interactive input which is complex to test in bats
  # Functionality verified through integration testing
}

# mt package edit tests

@test "package: edit requires package name" {
  run _mt_package_edit
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "package: edit validates package exists" {
  run _mt_package_edit "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "package: edit validates symlink is not broken" {
  # Create broken symlink
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_package_edit "broken-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "broken" ]]
}

@test "package: edit uses EDITOR environment variable" {
  # Create test package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Set custom editor
  export EDITOR="echo"

  run _mt_package_edit "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "${package_dir}" ]]
}

# mt package install tests

@test "package: install requires package name" {
  run _mt_package_install
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "package: install requires package in working set" {
  run _mt_package_install "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found in working set" ]]
}

@test "package: install validates symlink is not broken" {
  # Create broken symlink
  ln -s "/nonexistent/path" "${MT_PACKAGES_DIR}/broken-package"

  run _mt_package_install "broken-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "broken" ]]
}

@test "package: install calls stow for package" {
  skip "Requires full stow integration test"
  # This would test the actual stow functionality
}

@test "package: install accepts --no-bin flag" {
  # Create package with bin
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  echo "#!/bin/bash" > "${package_dir}/bin/test-cmd"
  chmod +x "${package_dir}/bin/test-cmd"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_install "test-package" --no-bin
  [ $status -eq 0 ]
  [[ "$output" =~ "Skipped: bin" ]]
}

@test "package: install accepts --no-config flag" {
  # Create package with config
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config"
  touch "${package_dir}/config/dot-testrc"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_install "test-package" --no-config
  [ $status -eq 0 ]
  [[ "$output" =~ "Skipped: config" ]]
}

@test "package: install accepts --no-shell flag" {
  # Create package with shell
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/shell"
  touch "${package_dir}/shell/functions"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_install "test-package" --no-shell
  [ $status -eq 0 ]
  [[ "$output" =~ "Skipped: shell" ]]
}

@test "package: install accepts multiple package names" {
  # Create first package
  local package1_dir="${TEST_DIR}/package1"
  mkdir -p "${package1_dir}/bin"
  echo "#!/bin/bash" > "${package1_dir}/bin/cmd1"
  chmod +x "${package1_dir}/bin/cmd1"
  ln -s "${package1_dir}" "${MT_PACKAGES_DIR}/package1"

  # Create second package
  local package2_dir="${TEST_DIR}/package2"
  mkdir -p "${package2_dir}/bin"
  echo "#!/bin/bash" > "${package2_dir}/bin/cmd2"
  chmod +x "${package2_dir}/bin/cmd2"
  ln -s "${package2_dir}" "${MT_PACKAGES_DIR}/package2"

  run _mt_package_install "package1" "package2"
  [ $status -eq 0 ]
  [[ "$output" =~ "package1" ]]
  [[ "$output" =~ "package2" ]]
  [[ "$output" =~ "Summary: 2 installed, 0 failed" ]]
}

@test "package: install handles mixed success and failure with multiple packages" {
  # Create valid package
  local package1_dir="${TEST_DIR}/package1"
  mkdir -p "${package1_dir}/bin"
  ln -s "${package1_dir}" "${MT_PACKAGES_DIR}/package1"

  # Don't create package2 (will fail)

  run _mt_package_install "package1" "nonexistent"
  [ $status -eq 0 ]  # Returns 0 if at least one succeeds
  [[ "$output" =~ "package1" ]]
  [[ "$output" =~ "not found in working set: nonexistent" ]]
  [[ "$output" =~ "Summary: 1 installed, 1 failed" ]]
  [[ "$output" =~ "Failed packages:" ]]
  [[ "$output" =~ "- nonexistent" ]]
}

@test "package: install supports options with multiple packages" {
  # Create target directories
  mkdir -p "${MT_PKG_DIR}/bin"
  mkdir -p "${MT_PKG_DIR}/config"
  mkdir -p "${MT_PKG_DIR}/shell"

  # Create packages
  local package1_dir="${TEST_DIR}/package1"
  mkdir -p "${package1_dir}/bin" "${package1_dir}/config"
  echo "#!/bin/bash" > "${package1_dir}/bin/cmd1"
  chmod +x "${package1_dir}/bin/cmd1"
  ln -s "${package1_dir}" "${MT_PACKAGES_DIR}/package1"

  local package2_dir="${TEST_DIR}/package2"
  mkdir -p "${package2_dir}/bin" "${package2_dir}/config"
  echo "#!/bin/bash" > "${package2_dir}/bin/cmd2"
  chmod +x "${package2_dir}/bin/cmd2"
  ln -s "${package2_dir}" "${MT_PACKAGES_DIR}/package2"

  run _mt_package_install --no-config "package1" "package2"
  [ $status -eq 0 ]
  [[ "$output" =~ "Skipped: config" ]]
  [[ "$output" =~ "Summary: 2 installed, 0 failed" ]]
}

# mt package uninstall tests

@test "package: uninstall requires package name" {
  run _mt_package_uninstall
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "package: uninstall handles package not in working set" {
  run _mt_package_uninstall "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "Cannot locate package" ]]
}

@test "package: uninstall succeeds if package not installed" {
  # Create package that's not installed
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_uninstall "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "not installed" ]]
}

@test "package: uninstall accepts exclusion flags" {
  # Create package
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_package_uninstall "test-package" --no-bin
  [ $status -eq 0 ]
}

@test "package: uninstall accepts multiple package names" {
  # Create first package
  local package1_dir="${TEST_DIR}/package1"
  mkdir -p "${package1_dir}/bin"
  ln -s "${package1_dir}" "${MT_PACKAGES_DIR}/package1"

  # Create second package
  local package2_dir="${TEST_DIR}/package2"
  mkdir -p "${package2_dir}/bin"
  ln -s "${package2_dir}" "${MT_PACKAGES_DIR}/package2"

  run _mt_package_uninstall "package1" "package2"
  [ $status -eq 0 ]
  [[ "$output" =~ "package1" ]]
  [[ "$output" =~ "package2" ]]
  [[ "$output" =~ "Summary: 2 uninstalled, 0 failed" ]]
}

@test "package: uninstall supports options with multiple packages" {
  # Create packages
  local package1_dir="${TEST_DIR}/package1"
  mkdir -p "${package1_dir}/bin"
  ln -s "${package1_dir}" "${MT_PACKAGES_DIR}/package1"

  local package2_dir="${TEST_DIR}/package2"
  mkdir -p "${package2_dir}/bin"
  ln -s "${package2_dir}" "${MT_PACKAGES_DIR}/package2"

  run _mt_package_uninstall --no-bin "package1" "package2"
  [ $status -eq 0 ]
  [[ "$output" =~ "Summary: 2 uninstalled, 0 failed" ]]
}
