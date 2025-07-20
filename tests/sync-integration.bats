#!/usr/bin/env bats

# Integration test for mt sync functionality

setup() {
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_LOG_LEVEL="ERROR"
  export MT_GIT_PROTOCOL_DEFAULT="https"
  export MT_GIT_HOST_DEFAULT="github.com"
  export MT_GIT_USER_DEFAULT="mbailey"
  
  # Create temporary test directory
  export TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  
  # Source libraries directly
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/git.sh"
  source "${MT_ROOT}/lib/sync.sh"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

@test "_mt_sync --dry-run shows planned operations" {
  cat > repos.txt << 'EOF'
mbailey/metool                # Default shared
user/example@v1.0   my-example # Custom name
EOF

  run _mt_sync --dry-run
  
  # Debug output
  echo "Output:" >&3
  echo "$output" >&3
  
  [ "$status" -eq 0 ]
  
  # Should show repos to sync
  [[ "$output" =~ "mbailey/metool" ]]
  # Check if version is preserved in output
  [[ "$output" =~ "user/example" ]]
  [[ "$output" =~ "shared" ]]
  [[ "$output" =~ "my-example" ]]
}

@test "_mt_sync --help shows usage" {
  run _mt_sync --help
  [ "$status" -eq 0 ]
  
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "mt sync" ]]
  [[ "$output" =~ "--dry-run" ]]
}