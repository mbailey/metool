#!/usr/bin/env bats

# Source the helper script
# shellcheck source=test_helper.bash
load test_helper

setup() {
  # Create a temporary directory for testing
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  
  # Create a working directory for the tests
  export WORK_DIR="${TMPDIR}/work"
  mkdir -p "${WORK_DIR}"
  cd "${WORK_DIR}"
  
  # Source the completion script
  source "${MT_ROOT}/shell/completions/mt.bash"
}

teardown() {
  cd "${BATS_TEST_DIRNAME}"
  rm -rf "${TMPDIR}"
}

@test "mt command completion includes sync" {
  COMP_WORDS=(mt sy)
  COMP_CWORD=1
  _mt_completions
  
  # Should complete to sync
  [[ " ${COMPREPLY[*]} " =~ " sync " ]]
}

@test "mt sync completion includes flags" {
  COMP_WORDS=(mt sync --)
  COMP_CWORD=2
  _mt_completions
  
  # Should include sync-specific flags
  [[ " ${COMPREPLY[*]} " =~ " --dry-run " ]]
  [[ " ${COMPREPLY[*]} " =~ " --file " ]]
  [[ " ${COMPREPLY[*]} " =~ " --default-strategy " ]]
}

@test "mt sync --default-strategy completion includes strategies" {
  COMP_WORDS=(mt sync --default-strategy sh)
  COMP_CWORD=3
  _mt_completions
  
  # Should complete strategy options
  [[ " ${COMPREPLY[*]} " =~ " shared " ]]
}