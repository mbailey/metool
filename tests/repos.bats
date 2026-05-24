#!/usr/bin/env bats

# Tests for lib/repos.sh -- mt git repos discovery.
#
# MT-66: warn on unparseable remote URL instead of silent skip.
# MT-68: accept ssh_config Host alias URL form (e.g. failmode:owner/repo).

bats_require_minimum_version 1.5.0

load test_helper

setup() {
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."

  # Insulate from the user's global gitconfig. Mike has
  # `url.ms2:git/repos/.insteadof failmode:mbailey/` rewrite rules that make
  # `git remote get-url origin` return a different URL than the one we set,
  # which silently invalidates any test using a rewriteable URL. Point
  # GIT_CONFIG_GLOBAL at /dev/null so tests see only what they configured.
  export GIT_CONFIG_GLOBAL=/dev/null

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
  _make_repo broken 'no-colon-no-scheme-nothing'

  run --separate-stderr -0 _mt_repos_discover .

  [ "$output" = "mbailey/keycutter" ]
  [[ "$stderr" == *"Cannot parse remote URL"* ]]
  [[ "$stderr" == *"no-colon-no-scheme-nothing"* ]]
}

@test "mt git repos: exit code remains 0 even when every repo is unparseable" {
  _make_repo broken1 'garbage-one'
  _make_repo broken2 'garbage-two'

  run --separate-stderr _mt_repos_discover .

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # Two warnings -- one per repo.
  warning_count=$(echo "$stderr" | grep -c "Cannot parse remote URL" || true)
  [ "$warning_count" -eq 2 ]
}

# ----------------------------------------------------------------------------
# MT-68: _mt_parse_git_url accepts ssh_config Host alias form
# ----------------------------------------------------------------------------

@test "_mt_parse_git_url: alias form host:owner/repo -> host:owner/repo" {
  run -0 _mt_parse_git_url 'failmode:mbailey/skillify'
  [ "$output" = 'failmode:mbailey/skillify' ]
}

@test "_mt_parse_git_url: alias form host:owner/repo.git -> .git stripped, prefix preserved" {
  run -0 _mt_parse_git_url 'failmode:mbailey/skillify.git'
  [ "$output" = 'failmode:mbailey/skillify' ]
}

@test "_mt_parse_git_url: alias form with deep path host:a/b/c.git -> host:a/b/c" {
  run -0 _mt_parse_git_url 'ms2:git/repos/foo.git'
  [ "$output" = 'ms2:git/repos/foo' ]
}

@test "_mt_parse_git_url: alias form with tilde host:~/path/repo.git -> tilde preserved" {
  # ms2:~/git/repos/mfp.git is a real remote in Mike's ~/Code/failmode/mbailey.
  # The tilde must pass through verbatim -- no shell expansion, no resolution.
  run -0 _mt_parse_git_url 'ms2:~/git/repos/mfp.git'
  [ "$output" = 'ms2:~/git/repos/mfp' ]
}

@test "_mt_parse_git_url: existing git@ SSH pattern still parses unchanged" {
  run -0 _mt_parse_git_url 'git@github.com:mbailey/keycutter.git'
  [ "$output" = 'mbailey/keycutter' ]
}

@test "_mt_parse_git_url: existing HTTPS pattern still parses unchanged (alias rule does NOT shadow)" {
  # Regression guard. The new alias-form regex `^([^:/@]+):(.+)$` would match
  # `https://github.com/owner/repo` if placed before the HTTPS patterns
  # ([^:/@]+ matches `https`, then `:`, then `//github.com/owner/repo`).
  # Ordering keeps it correct; this test fails loudly if anyone reorders.
  run -0 _mt_parse_git_url 'https://github.com/mbailey/keycutter.git'
  [ "$output" = 'mbailey/keycutter' ]

  run -0 _mt_parse_git_url 'https://github.com/mbailey/keycutter'
  [ "$output" = 'mbailey/keycutter' ]
}

@test "mt git repos: alias-form remote produces stdout entry, empty stderr" {
  _make_repo skillify 'failmode:mbailey/skillify.git'

  run --separate-stderr -0 _mt_repos_discover .

  # `.git` stripped, alias prefix preserved, alias matches dir basename so no
  # column-2 alias is appended.
  [ "$output" = 'failmode:mbailey/skillify' ]
  [ -z "$stderr" ]
}
