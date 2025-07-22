#!/usr/bin/env bats

# Source the helper script - disable shellcheck warning about relative path
# shellcheck source=test_helper.bash
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_PKG_DIR="${TMPDIR}/.metool"
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  
  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Source the required files directly
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/sync.sh"
  
  # Mock log functions to simplify output
  _mt_log() {
    local level="$1"
    shift
    echo "${level}: $*"
  }
  
  _mt_info() {
    echo "INFO: $*"
  }
  
  _mt_error() {
    echo "ERROR: $*"
    return 1
  }
  
  _mt_warning() {
    echo "WARNING: $*"
  }
  
  _mt_debug() {
    echo "DEBUG: $*"
  }
}

teardown() {
  cd "${BATS_TEST_DIRNAME}" # Return to the tests directory
  rm -rf "${TMPDIR}"        # Clean up temporary directory
}

# Test repos.txt parsing functionality

@test "_mt_parse_repos_file should handle empty file" {
  touch repos.txt
  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "_mt_parse_repos_file should handle file with only comments" {
  cat > repos.txt << 'EOF'
# This is a comment
# Another comment

# Empty line above and comment
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "_mt_parse_repos_file should parse simple repo entries" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
vendor/ui-lib
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  # Should output TSV format: repo strategy target
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  
  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+shared[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib[[:space:]]+shared[[:space:]]+ui-lib$ ]]
}

@test "_mt_parse_repos_file should handle repos with version specifications" {
  cat > repos.txt << 'EOF'
mbailey/mt-public@v1.0
vendor/ui-lib@main
internal/tools@abc123def
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')
  
  [[ "$line1" =~ ^mbailey/mt-public@v1.0[[:space:]]+shared[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@main[[:space:]]+shared[[:space:]]+ui-lib$ ]]
  [[ "$line3" =~ ^internal/tools@abc123def[[:space:]]+shared[[:space:]]+tools$ ]]
}

@test "_mt_parse_repos_file should handle target name specification" {
  cat > repos.txt << 'EOF'
mbailey/mt-public     custom-name
vendor/ui-lib@v2.0    my-ui-lib
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  
  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+shared[[:space:]]+custom-name$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+shared[[:space:]]+my-ui-lib$ ]]
}

@test "_mt_parse_repos_file should handle strategy specification" {
  cat > repos.txt << 'EOF'
mbailey/mt-public     mt-public     shared
vendor/ui-lib@v2.0    my-ui-lib     local
internal/tools        tools         shared
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')
  
  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+shared[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+local[[:space:]]+my-ui-lib$ ]]
  [[ "$line3" =~ ^internal/tools[[:space:]]+shared[[:space:]]+tools$ ]]
}

@test "_mt_parse_repos_file should handle inline comments" {
  cat > repos.txt << 'EOF'
mbailey/mt-public                   # My public tools
vendor/ui-lib@v2.0   my-ui   local  # UI library for project
# Full comment line
internal/tools       tools   shared # Internal company tools
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')
  
  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+shared[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+local[[:space:]]+my-ui$ ]]
  [[ "$line3" =~ ^internal/tools[[:space:]]+shared[[:space:]]+tools$ ]]
}

@test "_mt_parse_repos_file should handle mixed whitespace" {
  cat > repos.txt << 'EOF'
mbailey/mt-public		shared	  mt-public
	vendor/ui-lib@v2.0    my-ui     local
internal/tools   tools shared
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')
  
  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+shared[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+local[[:space:]]+my-ui$ ]]
  [[ "$line3" =~ ^internal/tools[[:space:]]+shared[[:space:]]+tools$ ]]
}

@test "_mt_parse_repos_file should return error for non-existent file" {
  run _mt_parse_repos_file non-existent.txt
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR:" ]]
  [[ "$output" =~ "repos file not found" ]]
}

@test "_mt_parse_repos_file should strip .git from default target names" {
  cat > repos.txt << 'EOF'
mbailey/repo.git
github.com_work:company/project.git
user/another.git  custom-name
user/explicit.git explicit.git  shared
EOF

  run _mt_parse_repos_file repos.txt
  [ "$status" -eq 0 ]
  
  # Check output line by line
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')
  local line4=$(echo "$output" | sed -n '4p')
  
  # Check that .git is stripped from default target names
  [[ "$line1" =~ ^mbailey/repo.git[[:space:]]+shared[[:space:]]+repo$ ]]
  [[ "$line2" =~ ^github.com_work:company/project.git[[:space:]]+shared[[:space:]]+project$ ]]
  [[ "$line3" =~ ^user/another.git[[:space:]]+shared[[:space:]]+custom-name$ ]]
  # But explicit target names are preserved as-is
  [[ "$line4" =~ ^user/explicit.git[[:space:]]+shared[[:space:]]+explicit.git$ ]]
}

# Test argument parsing

@test "_mt_sync_parse_args should default to current directory repos.txt" {
  touch repos.txt
  run _mt_sync_parse_args
  
  [ "$status" -eq 0 ]
  # Check that output contains the repos file and work dir
  # Use realpath to normalize paths for comparison
  local expected_repos="$(command realpath "${WORK_DIR}/repos.txt")"
  local expected_work="$(command realpath "${WORK_DIR}")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_sync_parse_args should handle directory argument" {
  mkdir -p test-project
  touch test-project/repos.txt
  run _mt_sync_parse_args test-project
  [ "$status" -eq 0 ]
  # Use realpath to normalize paths for comparison
  local expected_repos="$(command realpath "${WORK_DIR}/test-project/repos.txt")"
  local expected_work="$(command realpath "${WORK_DIR}/test-project")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_sync_parse_args should handle file argument" {
  mkdir -p test-project
  touch test-project/deps.txt
  run _mt_sync_parse_args test-project/deps.txt
  [ "$status" -eq 0 ]
  # Use realpath to normalize paths for comparison
  local expected_repos="$(command realpath "${WORK_DIR}/test-project/deps.txt")"
  local expected_work="$(command realpath "${WORK_DIR}/test-project")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_sync_parse_args should handle --file flag" {
  touch custom.txt
  run _mt_sync_parse_args --file custom.txt
  [ "$status" -eq 0 ]
  # Use realpath to normalize paths for comparison
  local expected_repos="$(command realpath "${WORK_DIR}/custom.txt")"
  local expected_work="$(command realpath "${WORK_DIR}")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_sync_parse_args should handle --dry-run flag" {
  touch repos.txt
  run _mt_sync_parse_args --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DRY_RUN=true" ]]
}

@test "_mt_sync_parse_args should handle --default-strategy flag" {
  touch repos.txt
  run _mt_sync_parse_args --default-strategy local
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DEFAULT_STRATEGY=local" ]]
}

@test "_mt_sync_parse_args should handle combined flags" {
  touch custom.txt
  run _mt_sync_parse_args --file custom.txt --dry-run --default-strategy local
  [ "$status" -eq 0 ]
  # Use realpath to normalize paths for comparison
  local expected_repos="$(command realpath "${WORK_DIR}/custom.txt")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "DRY_RUN=true" ]]
  [[ "$output" =~ "DEFAULT_STRATEGY=local" ]]
}

@test "_mt_sync_parse_args should return error for non-existent directory" {
  run _mt_sync_parse_args non-existent-dir
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR:" ]]
}

@test "_mt_sync_parse_args should return error for non-existent file" {
  run _mt_sync_parse_args non-existent.txt
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR:" ]]
}

# Test main sync function with dry-run

@test "_mt_sync should show dry-run output" {
  cat > repos.txt << 'EOF'
mbailey/mt-public     shared
vendor/ui-lib@v2.0    my-ui   local
EOF

  run _mt_sync --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DRY RUN - No changes will be made" ]]
  [[ "$output" =~ "mbailey/mt-public" ]]
  [[ "$output" =~ "vendor/ui-lib@v2.0" ]]
  [[ "$output" =~ "shared" ]]
  [[ "$output" =~ "local" ]]
}

@test "_mt_sync should show help with --help flag" {
  run _mt_sync --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "mt sync" ]]
  [[ "$output" =~ "--dry-run" ]]
}

@test "_mt_sync should handle environment variable MT_SYNC_DEFAULT_STRATEGY" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
EOF

  MT_SYNC_DEFAULT_STRATEGY=local run _mt_sync --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "mbailey/mt-public" ]]
  [[ "$output" =~ "local" ]]
}