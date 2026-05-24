#!/usr/bin/env bats

# Tests for lib/repos.sh -- mt git repos discovery.
#
# MT-66: warn on unparseable remote URL instead of silent skip.

bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."

  # Source under test
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/repos.sh"

  # Make _mt_warning emit a stable, parseable line on stderr so tests can
  # assert against it without depending on color codes or emoji prefixes.
  _mt_warning() {
    echo "WARNING: $*" >&2
  }

  cd "${TMPDIR}"
}

teardown() {
  cd "${BATS_TEST_DIRNAME}"
  rm -rf "${TMPDIR}"
}

# Helper: make a bare-ish "repo" with a given origin URL. We don't need a real
# git repo on the remote side -- _mt_repos_discover only reads `git remote
# get-url origin`, so an init + remote add is enough.
_make_repo() {
  local name="$1" url="$2"
  git init -q "$name"
  git -C "$name" remote add origin "$url"
}

@test "mt git repos: unparseable URL writes warning to stderr; nothing on stdout" {
  _make_repo broken 'totally-not-a-url'

  run --separate-stderr -0 _mt_repos_discover .

  [ -z "$output" ]
  [[ "$stderr" == *"Cannot parse remote URL"* ]]
  [[ "$stderr" == *"totally-not-a-url"* ]]
  [[ "$stderr" == *"broken"* ]]
}

@test "mt git repos: parseable URL produces stdout entry and empty stderr" {
  _make_repo keycutter 'git@github.com:mbailey/keycutter.git'

  run --separate-stderr -0 _mt_repos_discover .

  [ "$output" = "mbailey/keycutter" ]
  [ -z "$stderr" ]
}

@test "mt git repos: mixed parseable + unparseable -- one stdout line, one stderr warning" {
  _make_repo keycutter 'git@github.com:mbailey/keycutter.git'
  _make_repo broken 'ms2:git/repos/something.git'

  run --separate-stderr -0 _mt_repos_discover .

  [ "$output" = "mbailey/keycutter" ]
  [[ "$stderr" == *"Cannot parse remote URL"* ]]
  [[ "$stderr" == *"ms2:git/repos/something.git"* ]]
}

@test "mt git repos: exit code remains 0 even when every repo is unparseable" {
  _make_repo broken1 'ms2:git/repos/a.git'
  _make_repo broken2 'ms2:git/repos/b.git'

  run --separate-stderr _mt_repos_discover .

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # Two warnings -- one per repo.
  warning_count=$(echo "$stderr" | grep -c "Cannot parse remote URL" || true)
  [ "$warning_count" -eq 2 ]
}
