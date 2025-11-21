#!/usr/bin/env bats
# Tests for service commands (MT-11)

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
  source "${MT_ROOT}/lib/service.sh"
}

teardown() {
  # Clean up test directory
  if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
    rm -rf "${TEST_DIR}"
  fi
}

# Service helper function tests

@test "service: detect_os returns linux or macos" {
  result=$(_mt_service_detect_os)
  [[ "$result" == "linux" || "$result" == "macos" || "$result" == "unsupported" ]]
}

@test "service: is_root detects non-root user" {
  run _mt_service_is_root
  # Should fail unless running as root
  [ $status -ne 0 ] || [ $EUID -eq 0 ]
}

@test "service: get_files finds systemd user services" {
  # Skip on macOS
  [[ "$(uname)" == "Darwin" ]] && skip "systemd not available on macOS"

  # Create package with systemd service
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/dot-config/systemd/user"
  touch "${package_dir}/config/dot-config/systemd/user/test.service"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_get_files "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "systemd-user" ]]
  [[ "$output" =~ "test.service" ]]
}

@test "service: get_files finds systemd system services" {
  # Skip on macOS
  [[ "$(uname)" == "Darwin" ]] && skip "systemd not available on macOS"

  # Create package with systemd system service
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/etc/systemd/system"
  touch "${package_dir}/config/etc/systemd/system/test.service"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_get_files "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "systemd-system" ]]
  [[ "$output" =~ "test.service" ]]
}

@test "service: get_files finds launchd services" {
  if [[ "$OSTYPE" != "darwin"* ]]; then
    skip "launchd only available on macOS"
  fi

  # Create package with launchd plist
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/macos"
  touch "${package_dir}/config/macos/com.test.plist"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_get_files "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "launchd" ]]
  [[ "$output" =~ "com.test.plist" ]]
}

@test "service: get_files returns error for package without services" {
  # Create package without services
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_get_files "test-package"
  [ $status -ne 0 ]
}

# mt package service list tests

@test "service: list requires package name" {
  run _mt_service_list
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: list validates package exists" {
  run _mt_service_list "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "service: list shows no services message" {
  # Create package without services
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_list "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "No service files" ]]
}

@test "service: list shows systemd services" {
  # Skip on macOS
  [[ "$(uname)" == "Darwin" ]] && skip "systemd not available on macOS"

  # Create package with systemd service
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/dot-config/systemd/user"
  touch "${package_dir}/config/dot-config/systemd/user/test.service"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_list "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "test.service" ]]
  [[ "$output" =~ "systemd-user" ]]
}

@test "service: list shows launchd services" {
  if [[ "$OSTYPE" != "darwin"* ]]; then
    skip "launchd only available on macOS"
  fi

  # Create package with launchd plist
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/macos"
  touch "${package_dir}/config/macos/com.test.plist"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_list "test-package"
  [ $status -eq 0 ]
  [[ "$output" =~ "com.test.plist" ]]
  [[ "$output" =~ "launchd" ]]
}

# mt package service start tests

@test "service: start requires package name" {
  run _mt_service_start
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: start validates package exists" {
  run _mt_service_start "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "service: start requires package to be installed" {
  # Create package that's not installed
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/dot-config/systemd/user"
  touch "${package_dir}/config/dot-config/systemd/user/test.service"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_start "test-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "not installed" ]]
}

@test "service: start validates package has services" {
  # Create installed package without services
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  echo "#!/bin/bash" > "${package_dir}/bin/test-cmd"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  # Simulate installation
  mkdir -p "${MT_PKG_DIR}/bin"
  ln -s "${package_dir}/bin/test-cmd" "${MT_PKG_DIR}/bin/test-cmd"

  run _mt_service_start "test-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "No service files" ]]
}

# mt package service stop tests

@test "service: stop requires package name" {
  run _mt_service_stop
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: stop validates package exists" {
  run _mt_service_stop "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

# mt package service restart tests

@test "service: restart requires package name" {
  run _mt_service_restart
  [ $status -ne 0 ]
}

@test "service: restart validates package exists" {
  run _mt_service_restart "nonexistent"
  [ $status -ne 0 ]
}

# mt package service status tests

@test "service: status requires package name" {
  run _mt_service_status
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: status validates package exists" {
  run _mt_service_status "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "service: status validates package has services" {
  # Create package without services
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/bin"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_status "test-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "No service files" ]]
}

# mt package service enable tests

@test "service: enable requires package name" {
  run _mt_service_enable
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: enable validates package exists" {
  run _mt_service_enable "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "service: enable requires package to be installed" {
  # Create package that's not installed
  local package_dir="${TEST_DIR}/test-package"
  mkdir -p "${package_dir}/config/dot-config/systemd/user"
  touch "${package_dir}/config/dot-config/systemd/user/test.service"
  ln -s "${package_dir}" "${MT_PACKAGES_DIR}/test-package"

  run _mt_service_enable "test-package"
  [ $status -ne 0 ]
  [[ "$output" =~ "not installed" ]]
}

# mt package service disable tests

@test "service: disable requires package name" {
  run _mt_service_disable
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: disable validates package exists" {
  run _mt_service_disable "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

# mt package service logs tests

@test "service: logs requires package name" {
  run _mt_service_logs
  [ $status -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

@test "service: logs validates package exists" {
  run _mt_service_logs "nonexistent"
  [ $status -ne 0 ]
  [[ "$output" =~ "not found" ]]
}

@test "service: logs accepts -f flag" {
  skip "Requires actual service manager (journalctl/launchctl)"
}

@test "service: logs accepts -n flag" {
  skip "Requires actual service manager (journalctl/launchctl)"
}

# Service-specific name filtering tests

@test "service: start accepts specific service name" {
  skip "Requires actual service manager (systemctl/launchctl)"
}

@test "service: start validates specific service exists" {
  skip "Requires actual service manager (systemctl/launchctl)"
}
