#!/usr/bin/env bats

# Tests for lib/repos.sh -- mt git repos discovery.
#
# MT-66: warn on unparseable remote URL instead of silent skip.
# MT-68: accept ssh_config Host alias URL form (e.g. failmode:owner/repo).
# MT-70: --raw flag emits unrewritten URLs from .git/config.

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

# ----------------------------------------------------------------------------
# MT-70: --raw flag emits unrewritten URLs from .git/config
# ----------------------------------------------------------------------------

# Helper: set a local insteadOf rule on $TMPDIR's git config that rewrites
# `failmode:` to `ms2:git/repos/`. Scoped to the per-test gitconfig (we set
# GIT_CONFIG_GLOBAL=/dev/null in setup, so we point GIT_CONFIG_GLOBAL at a
# real file for the duration of these tests instead). Avoids polluting the
# host's real ~/.gitconfig.
_with_insteadof_rule() {
  local rule_file="${TMPDIR}/test.gitconfig"
  cat > "$rule_file" <<'EOF'
[url "ms2:git/repos/"]
  insteadOf = failmode:mbailey/
EOF
  export GIT_CONFIG_GLOBAL="$rule_file"
}

@test "mt git repos --raw: emits raw .git/config URL, not the insteadOf rewrite" {
  _with_insteadof_rule
  _make_repo skillify 'failmode:mbailey/skillify'

  # Sanity check: without --raw, the rewrite kicks in.
  run --separate-stderr -0 _mt_repos_discover .
  # ms2:git/repos/skillify (rewritten). The columnise step strips trailing
  # `.git` only when alias != repo_name; here we expect the rewritten form.
  [[ "$output" == *"ms2:git/repos/skillify"* ]]

  # With --raw, we get the raw form.
  run --separate-stderr -0 _mt_repos_discover --raw .
  [ "$output" = 'failmode:mbailey/skillify' ]
  [ -z "$stderr" ]
}

@test "mt git repos --raw: no insteadOf rules -- output identical to default" {
  # Without any rewrite rules, --raw and default must produce the same output.
  # Regression guard: --raw shouldn't introduce a parsing difference.
  _make_repo keycutter 'git@github.com:mbailey/keycutter.git'

  run --separate-stderr -0 _mt_repos_discover .
  local default_out="$output"

  run --separate-stderr -0 _mt_repos_discover --raw .
  [ "$output" = "$default_out" ]
  [ -z "$stderr" ]
}

@test "mt git repos --raw: round-trips every URL shape _mt_parse_git_url accepts" {
  # For each URL shape, --raw should pass it through _mt_parse_git_url and
  # produce the canonical entry, with no warning. This proves --raw composes
  # cleanly with the post-MT-68 parser.
  _make_repo a 'git@github.com:owner/a.git'
  _make_repo b 'git@github.com:owner/b'
  _make_repo c 'https://github.com/owner/c.git'
  _make_repo d 'https://github.com/owner/d'
  _make_repo e 'failmode:owner/e.git'
  _make_repo f 'failmode:owner/f'

  run --separate-stderr -0 _mt_repos_discover --raw .

  # All six repos should appear in output, none in stderr warnings.
  [ -z "$stderr" ]
  [[ "$output" == *"owner/a"* ]]
  [[ "$output" == *"owner/b"* ]]
  [[ "$output" == *"owner/c"* ]]
  [[ "$output" == *"owner/d"* ]]
  [[ "$output" == *"failmode:owner/e"* ]]
  [[ "$output" == *"failmode:owner/f"* ]]
}

@test "mt git repos --help: mentions --raw flag" {
  run -0 _mt_repos_discover --help
  [[ "$output" == *"--raw"* ]]
  [[ "$output" == *"insteadOf"* ]]
}
