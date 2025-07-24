#!/usr/bin/env bats

# Source the helper script
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_PKG_DIR="${TMPDIR}/.metool"
  export MT_LOG_LEVEL="ERROR"
  
  # Create test directories
  export TEST_DIR1="${TMPDIR}/test-dir1"
  export TEST_DIR2="${TMPDIR}/test-dir2"
  mkdir -p "${TEST_DIR1}"
  mkdir -p "${TEST_DIR2}"
  
  # Create test executable in test-dir1
  cat > "${TEST_DIR1}/test-executable" << 'EOL'
#!/bin/bash
echo "This is a test executable"
EOL
  chmod +x "${TEST_DIR1}/test-executable"
  
  # Create test function file in test-dir2
  export FUNCTIONS_FILE="${TEST_DIR2}/functions.sh"
  cat > "${FUNCTIONS_FILE}" << 'EOL'
#!/bin/bash

test_function() {
  echo "This is test function"
}

another_test_function() {
  echo "This is another test function"
}
EOL
  
  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Mock required functions
  _mt_error() { echo "ERROR: $*" >&2; }
  _mt_debug() { echo "DEBUG: $*"; }
  _mt_log() { echo "$@" >&2; }
  
  # Enable extdebug for declare -F to work
  shopt -s extdebug
  
  # Source the path functions library directly
  source "${MT_ROOT}/lib/path.sh"
  
  # Add test-dir1 to PATH
  export PATH="${TEST_DIR1}:${PATH}"
  
  # Source the functions file to make functions available
  source "${FUNCTIONS_FILE}"
}

teardown() {
  cd /
  rm -rf "${TMPDIR}"
}

@test "_mt_cd to function changes to function's source file directory" {
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to test_function
  _mt_cd test_function
  
  # Check we're in the directory containing the functions file
  [ "$PWD" = "$TEST_DIR2" ]
}

@test "_mt_cd to executable changes to executable's directory" {
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to test-executable
  _mt_cd test-executable
  
  # Check we're in the directory containing the executable
  [ "$PWD" = "$TEST_DIR1" ]
}

@test "_mt_cd with non-existent target fails with error" {
  # Start in work directory
  cd "${WORK_DIR}"
  
  # Try to cd to non-existent function/executable
  run _mt_cd nonexistent_target
  
  # Check it failed
  [ "$status" -eq 1 ]
  [ "$output" = "Error: 'nonexistent_target' not found" ]
  
  # Check we're still in work directory
  [ "$PWD" = "$WORK_DIR" ]
}

@test "_mt_cd with wrong number of arguments shows usage" {
  # Start in work directory
  cd "${WORK_DIR}"
  
  # Try to cd with no arguments
  run _mt_cd
  
  # Check it failed
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage: mt cd <file|function|executable>" ]]
}

@test "_mt_cd with multiple arguments shows usage" {
  # Start in work directory
  cd "${WORK_DIR}"
  
  # Need to source the functions in subshell
  run bash -c "
    source '${MT_ROOT}/lib/path.sh'
    _mt_cd arg1 arg2
  "
  
  # Check it failed
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage: mt cd <file|function|executable>" ]]
}

@test "_mt_cd prioritizes function over executable when both exist" {
  # Create an executable with same name as function
  cat > "${TEST_DIR1}/test_function" << 'EOL'
#!/bin/bash
echo "This is test_function executable"
EOL
  chmod +x "${TEST_DIR1}/test_function"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to test_function (should prefer the function)
  _mt_cd test_function
  
  # Check we're in the function's directory, not the executable's
  [ "$PWD" = "$TEST_DIR2" ]
}

@test "_mt_cd works with executable not in PATH" {
  # Remove test-dir1 from PATH
  export PATH="${PATH/${TEST_DIR1}:/}"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # Try to cd to test-executable (should fail since not in PATH)
  run _mt_cd test-executable
  
  # Check it failed
  [ "$status" -eq 1 ]
  [ "$output" = "Error: 'test-executable' not found" ]
}

@test "_mt_cd works with absolute path executable" {
  # Create executable with absolute path in PATH
  ABSOLUTE_BIN="${TMPDIR}/absolute-bin"
  mkdir -p "${ABSOLUTE_BIN}"
  cat > "${ABSOLUTE_BIN}/abs-test" << 'EOL'
#!/bin/bash
echo "Absolute path test"
EOL
  chmod +x "${ABSOLUTE_BIN}/abs-test"
  export PATH="${ABSOLUTE_BIN}:${PATH}"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to abs-test
  _mt_cd abs-test
  
  # Check we're in the absolute bin directory
  [ "$PWD" = "$ABSOLUTE_BIN" ]
}

@test "_mt_cd works with symlinked executable" {
  # Create a symlink to test-executable
  ln -s "${TEST_DIR1}/test-executable" "${TEST_DIR2}/linked-executable"
  export PATH="${TEST_DIR2}:${PATH}"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to linked-executable
  _mt_cd linked-executable
  
  # Check we're in the directory containing the symlink
  [ "$PWD" = "$TEST_DIR2" ]
}

@test "_mt_cd works with function defined in sourced file" {
  # Create another functions file
  ANOTHER_FUNCTIONS="${TMPDIR}/another-functions.sh"
  cat > "${ANOTHER_FUNCTIONS}" << 'EOL'
#!/bin/bash

remote_function() {
  echo "This is a remote function"
}
EOL
  
  # Source it
  source "${ANOTHER_FUNCTIONS}"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to remote_function
  _mt_cd remote_function
  
  # Check we're in the directory containing the source file
  [ "$PWD" = "$TMPDIR" ]
}

@test "_mt_cd handles function with spaces in directory path" {
  # Create directory with spaces
  SPACE_DIR="${TMPDIR}/dir with spaces"
  mkdir -p "${SPACE_DIR}"
  
  # Create functions file in space directory
  SPACE_FUNCTIONS="${SPACE_DIR}/space-functions.sh"
  cat > "${SPACE_FUNCTIONS}" << 'EOL'
#!/bin/bash

space_function() {
  echo "Function in directory with spaces"
}
EOL
  
  # Source it
  source "${SPACE_FUNCTIONS}"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to space_function
  _mt_cd space_function
  
  # Check we're in the directory with spaces
  [ "$PWD" = "${SPACE_DIR}" ]
}

@test "_mt_cd with bash builtin (no external command) fails" {
  # Start in work directory
  cd "${WORK_DIR}"
  
  # Try to cd to a bash builtin that has no external command
  # Use 'declare' which is a pure builtin with no external equivalent
  run _mt_cd declare
  
  # Check it failed (builtins don't have source files)
  [ "$status" -eq 1 ]
  [ "$output" = "Error: 'declare' not found" ]
}

@test "_mt_cd to mt function goes to MT_ROOT/shell" {
  # Create a mock mt function in our test environment
  mt() {
    echo "Mock mt function"
  }
  
  # Export MT_ROOT for this test
  export MT_ROOT="${TMPDIR}/mock-metool"
  mkdir -p "${MT_ROOT}/shell"
  
  # Create the mt source file
  cat > "${MT_ROOT}/shell/mt" << 'EOF'
#!/bin/bash
mt() {
  echo "Real mt function"
}
EOF
  
  # Source it to make the function available
  source "${MT_ROOT}/shell/mt"
  
  # Start in work directory
  cd "${WORK_DIR}"
  
  # cd to mt function
  _mt_cd mt
  
  # Check we're in the shell directory
  [ "$PWD" = "${MT_ROOT}/shell" ]
}