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

@test "mt git pull command completion" {
  COMP_WORDS=(mt git pu)
  COMP_CWORD=2
  _mt_completions

  # Should complete to pull and push
  [[ " ${COMPREPLY[*]} " =~ " pull " ]]
  [[ " ${COMPREPLY[*]} " =~ " push " ]]
}

@test "mt git pull completion includes flags" {
  COMP_WORDS=(mt git pull --)
  COMP_CWORD=3
  _mt_completions

  # Should include pull-specific flags
  [[ " ${COMPREPLY[*]} " =~ " --dry-run " ]]
  [[ " ${COMPREPLY[*]} " =~ " --quick " ]]
  [[ " ${COMPREPLY[*]} " =~ " --protocol " ]]
}

@test "mt git push completion includes flags" {
  COMP_WORDS=(mt git push --)
  COMP_CWORD=3
  _mt_completions

  # Should include push-specific flags
  [[ " ${COMPREPLY[*]} " =~ " --dry-run " ]]
  [[ " ${COMPREPLY[*]} " =~ " --force " ]]
}