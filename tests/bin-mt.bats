#!/usr/bin/env bats

# MT-79: bin/mt double-invocation regression tests.
#
# Background: bin/mt sources shell/mt and then runs `mt "$@"`. shell/mt
# itself ends with `mt "$@"` so its package-sourcing no-args path runs when
# users source it from ~/.bashrc. Without a guard, bin/mt-driven invocations
# fire `mt "$@"` twice -- once during sourcing, once after. These tests pin
# the single-invocation contract.

load test_helper

setup() {
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_PKG_DIR="${TMPDIR}/.metool"
  command mkdir -p "${MT_PKG_DIR}/bin" "${MT_PKG_DIR}/shell"

  # Pin a deterministic PATH so the system `mt` (if any) doesn't shadow the
  # bin/mt we want to test.
  export PATH="${MT_ROOT}/bin:${PATH}"
}

teardown() {
  rm -rf "${TMPDIR}"
}

@test "bin/mt: unknown command emits the error exactly once" {
  run bash -c "${MT_ROOT}/bin/mt mt-79-no-such-cmd 2>&1"
  [ "$status" -ne 0 ]
  count=$(echo "${output}" | grep -c "Unknown command: mt-79-no-such-cmd" || true)
  [ "${count}" -eq 1 ]
}

@test "bin/mt: -h produces help text without duplicating it" {
  # `mt -h` would historically fire twice via the binary wrapper. The full
  # help output appears once when the fix is correct.
  run bash -c "${MT_ROOT}/bin/mt -h 2>&1"
  usage_count=$(echo "${output}" | grep -c -E "^Usage:" || true)
  # Some commands don't emit "Usage:" verbatim; tolerate 0 or 1, fail on >1.
  [ "${usage_count}" -le 1 ]
}

@test "shell/mt: interactive sourcing still auto-invokes mt at the bottom" {
  # When _MT_BIN_WRAPPER is unset (the interactive ~/.bashrc case),
  # sourcing shell/mt MUST still trigger the no-args package-sourcing path
  # so that adding `source path/to/shell/mt` to a user's rc remains a
  # one-liner setup.
  run bash -c "
    unset _MT_BIN_WRAPPER
    source '${MT_ROOT}/shell/mt'
    type -t mt
  "
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q '^function$'
}

@test "shell/mt: sourcing under _MT_BIN_WRAPPER=1 defines mt but does NOT run it" {
  # With the guard set (the binary-wrapper case), sourcing shell/mt should
  # define `mt` but NOT run it -- the wrapper calls `mt "$@"` itself
  # afterwards.
  run bash -c "
    export _MT_BIN_WRAPPER=1
    # Pass an arg that, if mt() were auto-invoked, would emit a known error
    set -- mt-79-guard-canary
    source '${MT_ROOT}/shell/mt'
    type -t mt
    echo 'NO_AUTO_INVOKE_OK'
  "
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q 'NO_AUTO_INVOKE_OK'
  # Crucially, we should NOT see the "Unknown command" error -- that would
  # mean shell/mt auto-invoked mt despite the guard.
  ! echo "${output}" | grep -q "Unknown command: mt-79-guard-canary"
}
