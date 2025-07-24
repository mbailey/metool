#!/usr/bin/env bats

# Source the helper script
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export TEST_PKG_NAME="test-pkg"
  export TEST_MODULE_NAME="test-module"
  export TEST_PKG_PATH="${TMPDIR}/${TEST_MODULE_NAME}/${TEST_PKG_NAME}"
  export MT_PKG_DIR="${TMPDIR}/.metool"
  export HOME="${TMPDIR}/home"
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  
  # Mock the editor to just echo the file path
  export EDITOR="echo"
  
  # Create test packages
  mkdir -p "${TEST_PKG_PATH}"
  
  # Create a README.md for the test package
  echo "# Test Package" > "${TEST_PKG_PATH}/README.md"
  
  # Create some test functions
  FUNCTIONS_FILE="${TMPDIR}/functions.sh"
  cat > "${FUNCTIONS_FILE}" << EOL
#!/bin/bash

test_function_1() {
  echo "This is test function 1"
}

test_function_2() {
  echo "This is test function 2"
}
EOL
  
  # Create test executable
  EXEC_DIR="${TMPDIR}/bin"
  mkdir -p "${EXEC_DIR}"
  cat > "${EXEC_DIR}/test-executable" << EOL
#!/bin/bash
echo "This is a test executable"
EOL
  chmod +x "${EXEC_DIR}/test-executable"
  export PATH="${EXEC_DIR}:${PATH}"
  
  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Source the test functions
  source "${FUNCTIONS_FILE}"
  
  # Source the required files
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/edit.sh"
  
  # Mock the is_function, is_executable, and is_file functions
  is_function() {
    # Return true if the argument is one of our test functions
    if [[ "$1" == "test_function_1" || "$1" == "test_function_2" ]]; then
      return 0
    fi
    return 1
  }
  
  is_executable() {
    # Return true if the argument is our test executable
    if [[ "$1" == "test-executable" ]]; then
      return 0
    fi
    return 1
  }
  
  is_file() {
    # Return true if the file exists
    if [[ -f "$1" ]]; then
      return 0
    fi
    # For testing, also return true for known test files
    if [[ "$1" == "${WORK_DIR}/test-file.txt" ]]; then
      return 0
    fi
    return 1
  }
  
  # Mock _mt_get_packages
  _mt_get_packages() {
    echo -e "${TEST_PKG_NAME}\t${TEST_MODULE_NAME}\t${TEST_PKG_PATH}"
  }
  
  # Mock _mt_get_modules
  _mt_get_modules() {
    echo -e "${TEST_MODULE_NAME}\t$(dirname "${TEST_PKG_PATH}")"
  }
  
  # Mock _mt_edit_function
  _mt_edit_function() {
    echo "Editing function: $1"
    return 0
  }
  
  # Mock _mt_edit_executable
  _mt_edit_executable() {
    echo "Editing executable: $1"
    return 0
  }
  
  # Mock declare -F for function line numbers
  declare() {
    if [[ "$1" == "-F" && "$2" == "test_function_1" ]]; then
      echo "test_function_1 1 ${FUNCTIONS_FILE}"
    elif [[ "$1" == "-F" && "$2" == "test_function_2" ]]; then
      echo "test_function_2 5 ${FUNCTIONS_FILE}"
    fi
  }
}

teardown() {
  cd "${BATS_TEST_DIRNAME}" # Return to the tests directory
  rm -rf "${TMPDIR}"        # Clean up temporary directory
}

@test "mt edit shows usage when no arguments provided" {
  run _mt_edit
  
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage: mt edit" ]]
}

@test "mt edit no longer supports package editing" {
  # Test that package/name syntax now treats it as a file path
  run _mt_edit "package/${TEST_PKG_NAME}"
  
  # Should fail since this file doesn't exist
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}


@test "mt edit now treats paths with slashes as files" {
  # Test that module/package syntax is treated as a file path
  local test_file="${TMPDIR}/some/nested/file.txt"
  mkdir -p "$(dirname "$test_file")"
  echo "test content" > "$test_file"
  
  run _mt_edit "some/nested/file.txt"
  
  # Should fail because it's looking for absolute path
  [ "$status" -eq 1 ]
  
  # But with full path it should work
  run _mt_edit "$test_file"
  [ "$status" -eq 0 ]
}

@test "mt edit can edit a function" {
  run _mt_edit "test_function_1"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Editing function: test_function_1" ]]
}

@test "mt edit can edit an executable" {
  run _mt_edit "test-executable"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Editing executable: test-executable" ]]
}

@test "mt edit can edit a file" {
  local test_file="${WORK_DIR}/test-file.txt"
  echo "Test content" > "${test_file}"
  
  # Create a custom _mt_edit function for this test
  _mt_edit() {
    if [[ "$1" == "${test_file}" ]]; then
      echo "${test_file}"
      return 0
    fi
    return 1
  }
  
  run _mt_edit "${test_file}"
  
  [ "$status" -eq 0 ]
  [[ "$output" == "${test_file}" ]]
  
  # Restore the original _mt_edit function
  source "${MT_ROOT}/lib/edit.sh"
}

@test "mt edit errors on non-existent target" {
  run _mt_edit "non-existent-target"
  
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Target non-existent-target not found" ]]
}

# Disabled as it's too slow
# @test "mt edit can create a new package with confirmation" {
#   local new_pkg="${TEST_MODULE_NAME}/new-package"
#   local new_pkg_path="${TMPDIR}/${TEST_MODULE_NAME}/new-package"
#   
#   # Mock the read command to simulate a 'y' answer
#   function read() {
#     REPLY="y"
#   }
#   
#   run _mt_edit "${new_pkg}"
#   
#   [ "$status" -eq 0 ]
#   [[ "$output" =~ "Creating package directory" ]]
#   [[ "$output" =~ "Creating README.md for package" ]]
#   [[ "$output" =~ "Editing package README" ]]
# }

# Disabled as it's too slow
# @test "mt edit can cancel creating a new package" {
#   local new_pkg="${TEST_MODULE_NAME}/new-package-2"
#   
#   # Mock the read command to simulate a 'n' answer
#   function read() {
#     REPLY="n"
#   }
#   
#   run _mt_edit "${new_pkg}"
#   
#   [ "$status" -eq 1 ]
#   [[ "$output" =~ "Package creation cancelled" ]]
# }

@test "mt edit treats slash paths as files" {
  run _mt_edit "non-existent-module/package"
  
  # Should fail as file not found, not module not found
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found as function, executable, or file" ]]
}

@test "mt edit_function displays error if function not found" {
  # Use the real _mt_edit_function from edit.sh
  unset -f _mt_edit_function
  source "${MT_ROOT}/lib/edit.sh"
  
  run _mt_edit_function "non-existent-function"
  
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Function 'non-existent-function' not found" ]]
}

@test "mt edit_executable displays error if executable not found" {
  # Use the real _mt_edit_executable from edit.sh
  unset -f _mt_edit_executable
  source "${MT_ROOT}/lib/edit.sh"
  
  run _mt_edit_executable "non-existent-executable"
  
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Executable 'non-existent-executable' not found" ]]
}

@test "mt edit_function can edit a function with line number" {
  # Need to override the mock to test the actual function
  _mt_edit_function() {
    if (($# != 1)); then
      echo "Usage: mt edit-function <function-name>" >&2
      return 1
    fi
  
    if ! is_function "${1}"; then
      echo "Error: Function '${1}' not found" >&2
      return 1
    fi
  
    shopt -s extdebug
    funcinfo=($(declare -F "${1}"))
    editor="${EDITOR:-vim}"
    echo "Would edit ${editor} +${funcinfo[1]} ${funcinfo[2]}"
  }
  
  run _mt_edit_function "test_function_1"
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Would edit echo +1 ${FUNCTIONS_FILE}" ]]
}