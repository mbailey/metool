#!/usr/bin/env bats

# MT-72 tests-001: canonical URL parser test suite.
#
# One test per row of behaviour-matrix.md covering _mt_url_parse,
# _mt_url_canonicalise, and _mt_url_to_fetch. Plus the D9 anti-regression
# test (matrix mandate) and the regex-ordering shadow guard from MT-68's
# silent-shadowing bug class.

load test_helper

setup() {
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."

  # MT-68 trap: any test that touches `git remote get-url` (directly or via
  # `insteadOf` rewrites) silently fails without this. The parser itself
  # doesn't shell out to git, but the surrounding helpers do, and the harness
  # might pick up the user's ~/.gitconfig insteadOf rules and rewrite test
  # inputs out from under us.
  export GIT_CONFIG_GLOBAL=/dev/null

  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/git.sh"

  export MT_GIT_HOST_DEFAULT="github.com"
  export MT_GIT_USER_DEFAULT="mbailey"
  unset MT_GIT_PROTOCOL_DEFAULT
}

# ----------------------------------------------------------------------
# _mt_url_parse -- one test per matrix row (in-scope for the parser)
# ----------------------------------------------------------------------

# Row 1: SSH with .git
@test "parse row 1: git@github.com:mbailey/keycutter.git (SSH with .git)" {
  declare -A p
  _mt_url_parse "git@github.com:mbailey/keycutter.git" p
  [ "${p[type]}" = "ssh" ]
  [ "${p[user]}" = "git" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[identity]}" = "" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
  [ "${p[path]}" = "mbailey/keycutter" ]
  [ "${p[has_git_suffix]}" = "1" ]
}

# Row 2: SSH no-.git
@test "parse row 2: git@github.com:mbailey/keycutter (SSH no .git)" {
  declare -A p
  _mt_url_parse "git@github.com:mbailey/keycutter" p
  [ "${p[type]}" = "ssh" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
  [ "${p[has_git_suffix]}" = "0" ]
}

# Row 3: SSH with identity
@test "parse row 3: git@github.com_mbailey:mbailey/keycutter.git (SSH with identity)" {
  declare -A p
  _mt_url_parse "git@github.com_mbailey:mbailey/keycutter.git" p
  [ "${p[type]}" = "ssh" ]
  [ "${p[user]}" = "git" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[identity]}" = "mbailey" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
}

# Row 4: SSH deep path
@test "parse row 4: git@host:org/sub/repo.git (SSH deep path)" {
  declare -A p
  _mt_url_parse "git@host:org/sub/repo.git" p
  [ "${p[type]}" = "ssh" ]
  [ "${p[host]}" = "host" ]
  [ "${p[owner]}" = "org" ]
  [ "${p[repo_name]}" = "repo" ]
  [ "${p[path]}" = "org/sub/repo" ]
}

# Row 5: HTTPS with .git
@test "parse row 5: https://github.com/mbailey/keycutter.git (HTTPS with .git)" {
  declare -A p
  _mt_url_parse "https://github.com/mbailey/keycutter.git" p
  [ "${p[type]}" = "https" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
  [ "${p[has_git_suffix]}" = "1" ]
}

# Row 6: HTTPS no-.git
@test "parse row 6: https://github.com/mbailey/keycutter (HTTPS no .git)" {
  declare -A p
  _mt_url_parse "https://github.com/mbailey/keycutter" p
  [ "${p[type]}" = "https" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
  [ "${p[has_git_suffix]}" = "0" ]
}

# Row 7: HTTP (D4: distinguished from HTTPS)
@test "parse row 7: http://host/owner/repo (HTTP, distinct type from https)" {
  declare -A p
  _mt_url_parse "http://host/owner/repo" p
  [ "${p[type]}" = "http" ]
  [ "${p[host]}" = "host" ]
  [ "${p[owner]}" = "owner" ]
  [ "${p[repo_name]}" = "repo" ]
}

# Row 8: HTTPS deep path
@test "parse row 8: https://host/group/subgroup/repo.git (HTTPS deep path)" {
  declare -A p
  _mt_url_parse "https://host/group/subgroup/repo.git" p
  [ "${p[type]}" = "https" ]
  [ "${p[host]}" = "host" ]
  [ "${p[owner]}" = "group" ]
  [ "${p[repo_name]}" = "repo" ]
  [ "${p[path]}" = "group/subgroup/repo" ]
}

# Row 9: ssh_config alias, no .git
@test "parse row 9: failmode:mbailey/skillify (alias, no .git)" {
  declare -A p
  _mt_url_parse "failmode:mbailey/skillify" p
  [ "${p[type]}" = "alias" ]
  [ "${p[host]}" = "failmode" ]
  [ "${p[identity]}" = "" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "skillify" ]
}

# Row 10: ssh_config alias with .git
@test "parse row 10: failmode:mbailey/skillify.git (alias, .git stripped)" {
  declare -A p
  _mt_url_parse "failmode:mbailey/skillify.git" p
  [ "${p[type]}" = "alias" ]
  [ "${p[host]}" = "failmode" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "skillify" ]
  [ "${p[has_git_suffix]}" = "1" ]
}

# Row 11: ssh_config alias, deep path
@test "parse row 11: ms2:git/repos/foo.git (alias deep path)" {
  declare -A p
  _mt_url_parse "ms2:git/repos/foo.git" p
  [ "${p[type]}" = "alias" ]
  [ "${p[host]}" = "ms2" ]
  [ "${p[path]}" = "git/repos/foo" ]
  [ "${p[repo_name]}" = "foo" ]
}

# Row 12: ssh_config alias, tilde path
@test "parse row 12: ms2:~/git/repos/mfp.git (alias tilde path)" {
  declare -A p
  _mt_url_parse "ms2:~/git/repos/mfp.git" p
  [ "${p[type]}" = "alias" ]
  [ "${p[host]}" = "ms2" ]
  [ "${p[path]}" = "~/git/repos/mfp" ]
  [ "${p[repo_name]}" = "mfp" ]
}

# Row 13: bare owner/repo
@test "parse row 13: mbailey/keycutter (bare shorthand)" {
  declare -A p
  _mt_url_parse "mbailey/keycutter" p
  [ "${p[type]}" = "shorthand" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
}

# Row 14: host shorthand
@test "parse row 14: github.com/owner/repo (host shorthand, dot in first segment)" {
  declare -A p
  _mt_url_parse "github.com/owner/repo" p
  [ "${p[type]}" = "shorthand" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "owner" ]
  [ "${p[repo_name]}" = "repo" ]
}

# Row 15: SSH shorthand :owner/repo
@test "parse row 15: :mbailey/keycutter (SSH shorthand)" {
  declare -A p
  _mt_url_parse ":mbailey/keycutter" p
  [ "${p[type]}" = "shorthand" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
}

# Row 16: underscore-identity (D5: expansion runs first)
@test "parse row 16: _mbailey:mbailey/keycutter (underscore-identity expanded)" {
  declare -A p
  _mt_url_parse "_mbailey:mbailey/keycutter" p
  [ "${p[host]}" = "github.com" ]
  [ "${p[identity]}" = "mbailey" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
}

# Row 17: underscore auto-identity
@test "parse row 17: _:mbailey/keycutter (auto-identity expanded)" {
  declare -A p
  _mt_url_parse "_:mbailey/keycutter" p
  [ "${p[host]}" = "github.com" ]
  [ "${p[identity]}" = "mbailey" ]
  [ "${p[owner]}" = "mbailey" ]
  [ "${p[repo_name]}" = "keycutter" ]
}

# Row 18: malformed auto-identity rejected
@test "parse row 18: _:not-owner-repo-format (auto-identity invalid, returns 1)" {
  declare -A p
  run _mt_url_parse "_:not-owner-repo-format" p
  [ "$status" -eq 1 ]
}

# Row 19: local directory path
@test "parse row 19: /path/to/repo (absolute local path)" {
  declare -A p
  _mt_url_parse "/path/to/repo" p
  [ "${p[type]}" = "local" ]
  [ "${p[path]}" = "/path/to/repo" ]
}

@test "parse row 19: . (current directory)" {
  declare -A p
  _mt_url_parse "." p
  [ "${p[type]}" = "local" ]
  [ "${p[path]}" = "." ]
}

@test "parse row 19: ~/Code/foo (tilde-home local path)" {
  declare -A p
  _mt_url_parse "~/Code/foo" p
  [ "${p[type]}" = "local" ]
  [ "${p[path]}" = "~/Code/foo" ]
}

# Row 21: pinned version (D8: @version field exposed)
@test "parse row 21: owner/repo@v1.2.3 (pinned version split off)" {
  declare -A p
  _mt_url_parse "owner/repo@v1.2.3" p
  [ "${p[type]}" = "shorthand" ]
  [ "${p[owner]}" = "owner" ]
  [ "${p[repo_name]}" = "repo" ]
  [ "${p[version]}" = "v1.2.3" ]
}

# ----------------------------------------------------------------------
# D9 anti-regression -- matrix MANDATES this test exists.
#
# `${repo_name%%@*}` greedily strips from the FIRST @, so for any URL
# starting with `git@`, repo_name becomes literally `git`. The new
# parser MUST use the anchored regex `@[^/:@]+$` instead. This test
# fails loudly if a future contributor reverts to `%%@*`.
# ----------------------------------------------------------------------

@test "D9 anti-regression: git@host:owner/repo.git -> repo_name=repo (NOT 'git')" {
  declare -A p
  _mt_url_parse "git@github.com:mbailey/keycutter.git" p
  [ "${p[repo_name]}" = "keycutter" ]
  [ "${p[repo_name]}" != "git" ]
}

@test "D9 anti-regression: bare git@host:owner/repo -> repo_name=repo" {
  declare -A p
  _mt_url_parse "git@host:owner/repo" p
  [ "${p[repo_name]}" = "repo" ]
  [ "${p[repo_name]}" != "git" ]
}

@test "D9 anti-regression: SSH with identity preserves repo_name (no @-strip damage)" {
  declare -A p
  _mt_url_parse "git@github.com_mbailey:mbailey/keycutter.git" p
  [ "${p[repo_name]}" = "keycutter" ]
}

@test "D9 anti-regression: SSH + @version splits both cleanly" {
  declare -A p
  _mt_url_parse "git@github.com:owner/repo.git@v1.2.3" p
  [ "${p[repo_name]}" = "repo" ]
  [ "${p[version]}" = "v1.2.3" ]
}

# ----------------------------------------------------------------------
# Shadow guard -- the MT-68 silent-shadowing bug class.
#
# The alias-form regex `^([^/:@]+):(.+)$` is a catch-all. If a future
# contributor reorders the regex chain so it runs before the https://
# branch, then `https://github.com/owner/repo` would silently classify
# as type=alias with host=https, path=//github.com/owner/repo. These
# tests fail loudly the moment that reorder happens.
# ----------------------------------------------------------------------

@test "shadow guard: https:// MUST classify as https (alias regex must NOT run first)" {
  declare -A p
  _mt_url_parse "https://github.com/owner/repo" p
  [ "${p[type]}" = "https" ]
  [ "${p[host]}" = "github.com" ]
  # If the alias catch-all matched first, host would be "https" and path
  # would start with "//" -- explicitly assert it doesn't.
  [ "${p[host]}" != "https" ]
}

@test "shadow guard: http:// MUST classify as http (not alias)" {
  declare -A p
  _mt_url_parse "http://example.com/owner/repo" p
  [ "${p[type]}" = "http" ]
  [ "${p[host]}" != "http" ]
}

@test "shadow guard: user@host: MUST classify as ssh (not alias)" {
  declare -A p
  _mt_url_parse "git@github.com:owner/repo" p
  [ "${p[type]}" = "ssh" ]
  [ "${p[user]}" = "git" ]
}

@test "shadow guard: host shorthand with dot MUST classify as shorthand (host=full hostname)" {
  declare -A p
  _mt_url_parse "github.com/owner/repo" p
  [ "${p[type]}" = "shorthand" ]
  [ "${p[host]}" = "github.com" ]
  [ "${p[owner]}" = "owner" ]
  # If bare-shorthand matched first, host would default to github.com but
  # path would be "github.com/owner" -- assert path is owner/repo, not that.
  [ "${p[path]}" = "owner/repo" ]
}

@test "shadow guard: alias-form catch-all only fires for non-URL hostnames" {
  # failmode has no `://`, no `@`, no `.` in the host part -- this is the
  # one case alias MUST handle. The shadow guard confirms it still does.
  declare -A p
  _mt_url_parse "failmode:owner/repo" p
  [ "${p[type]}" = "alias" ]
  [ "${p[host]}" = "failmode" ]
}

# ----------------------------------------------------------------------
# _mt_url_canonicalise -- .repos.txt-shape output
# ----------------------------------------------------------------------

@test "canonicalise: SSH default host -> owner/repo" {
  run _mt_url_canonicalise "git@github.com:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "mbailey/keycutter" ]
}

@test "canonicalise: SSH with identity -> _identity:owner/repo" {
  run _mt_url_canonicalise "git@github.com_mbailey:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "_mbailey:mbailey/keycutter" ]
}

@test "canonicalise: SSH non-default host -> host:owner/repo" {
  run _mt_url_canonicalise "git@gitlab.com:user/project.git"
  [ "$status" -eq 0 ]
  [ "$output" = "gitlab.com:user/project" ]
}

@test "canonicalise: HTTPS -> owner/repo (host info dropped)" {
  run _mt_url_canonicalise "https://github.com/mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "mbailey/keycutter" ]
}

@test "canonicalise: HTTP -> path (no host)" {
  run _mt_url_canonicalise "http://host/owner/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "owner/repo" ]
}

@test "canonicalise: alias preserved verbatim" {
  run _mt_url_canonicalise "failmode:mbailey/skillify.git"
  [ "$status" -eq 0 ]
  [ "$output" = "failmode:mbailey/skillify" ]
}

@test "canonicalise: shorthand is already canonical" {
  run _mt_url_canonicalise "mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "mbailey/keycutter" ]
}

@test "canonicalise: underscore-identity round-trips to _identity:owner/repo" {
  run _mt_url_canonicalise "_mbailey:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "_mbailey:mbailey/keycutter" ]
}

@test "canonicalise: local path is not canonicalisable (returns 1)" {
  run _mt_url_canonicalise "/path/to/repo"
  [ "$status" -eq 1 ]
}

# ----------------------------------------------------------------------
# _mt_url_to_fetch -- fetchable URL
# ----------------------------------------------------------------------

@test "to_fetch: SSH -> git@host:path.git" {
  run _mt_url_to_fetch "git@github.com:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "to_fetch: SSH adds .git when missing" {
  run _mt_url_to_fetch "git@github.com:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "to_fetch: SSH with identity reassembles host_identity" {
  run _mt_url_to_fetch "git@github.com_mbailey:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "to_fetch: HTTPS preserves protocol" {
  run _mt_url_to_fetch "https://github.com/mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/mbailey/keycutter.git" ]
}

@test "to_fetch: HTTP preserves protocol (D4: not silently promoted to https)" {
  run _mt_url_to_fetch "http://host/owner/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "http://host/owner/repo.git" ]
}

@test "to_fetch: alias gets git@ prefix and .git suffix" {
  run _mt_url_to_fetch "failmode:mbailey/skillify"
  [ "$status" -eq 0 ]
  [ "$output" = "git@failmode:mbailey/skillify.git" ]
}

@test "to_fetch: bare shorthand uses MT_GIT_HOST_DEFAULT (git protocol default)" {
  run _mt_url_to_fetch "mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

@test "to_fetch: bare shorthand respects MT_GIT_PROTOCOL_DEFAULT=https" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  run _mt_url_to_fetch "mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/mbailey/keycutter.git" ]
}

# Host-shorthand fetch-URL: host-shorthand unifies with bare-shorthand under
# type=shorthand and both apply MT_GIT_PROTOCOL_DEFAULT. Pre-consolidation the
# host-shorthand branch forced HTTPS unconditionally; see D10 in
# behaviour-matrix.md for the rationale and the env-var escape hatch.
@test "to_fetch: host shorthand applies MT_GIT_PROTOCOL_DEFAULT (default git/ssh)" {
  run _mt_url_to_fetch "github.com/owner/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:owner/repo.git" ]
}

@test "to_fetch: host shorthand respects MT_GIT_PROTOCOL_DEFAULT=https (escape hatch for the old always-HTTPS contract)" {
  export MT_GIT_PROTOCOL_DEFAULT="https"
  run _mt_url_to_fetch "gitlab.com/group/project"
  [ "$status" -eq 0 ]
  [ "$output" = "https://gitlab.com/group/project.git" ]
}

@test "to_fetch: underscore auto-identity expands to host_identity" {
  run _mt_url_to_fetch "_:mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com_mbailey:mbailey/keycutter.git" ]
}

@test "to_fetch: SSH shorthand :owner/repo uses default host" {
  run _mt_url_to_fetch ":mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:mbailey/keycutter.git" ]
}

# ----------------------------------------------------------------------
# Round-trip property: canon(canon(url)) == canon(url)
#
# The behaviour-matrix documents this as the property the new parser
# must satisfy. Once `url` is in canonical form, re-canonicalising it
# is a no-op. Catches the class of bug where storing a URL in
# .repos.txt and reading it back corrupts the URL.
# ----------------------------------------------------------------------

_assert_roundtrip() {
  local url="$1"
  local first second
  first=$(_mt_url_canonicalise "$url")
  second=$(_mt_url_canonicalise "$first")
  [ "$first" = "$second" ] || {
    echo "roundtrip failed: input=$url first=$first second=$second"
    return 1
  }
}

@test "roundtrip: SSH with .git" {
  _assert_roundtrip "git@github.com:mbailey/keycutter.git"
}

@test "roundtrip: SSH with identity" {
  _assert_roundtrip "git@github.com_mbailey:mbailey/keycutter.git"
}

@test "roundtrip: HTTPS with .git" {
  _assert_roundtrip "https://github.com/mbailey/keycutter.git"
}

@test "roundtrip: ssh_config alias with .git" {
  _assert_roundtrip "failmode:mbailey/skillify.git"
}

@test "roundtrip: bare shorthand" {
  _assert_roundtrip "mbailey/keycutter"
}

@test "roundtrip: underscore-identity" {
  _assert_roundtrip "_mbailey:mbailey/keycutter"
}

@test "roundtrip: underscore auto-identity" {
  _assert_roundtrip "_:mbailey/keycutter"
}

@test "roundtrip: host shorthand" {
  _assert_roundtrip "github.com/owner/repo"
}

# ----------------------------------------------------------------------
# _mt_url_to_host -- MT-73 ControlMaster pre-warm helper.
#
# The host string is what ssh keys its master socket off. Distinct
# identities (host_identity form) must produce distinct strings so each
# gets its own master socket. ssh_config Host aliases (no dot) are
# returned verbatim (ControlMaster keys off the alias, not the resolved
# hostname).
#
# Matrix mirrors the table in MT-73 design.md.
# ----------------------------------------------------------------------

@test "to_host: SSH git@host:path -> host" {
  run _mt_url_to_host "git@github.com:foo/bar.git"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com" ]
}

@test "to_host: SSH git@host:path (no .git) -> host" {
  run _mt_url_to_host "git@github.com:foo/bar"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com" ]
}

@test "to_host: ssh:// url -> host (port stripped)" {
  run _mt_url_to_host "ssh://git@github.com/foo/bar.git"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com" ]
}

@test "to_host: ssh:// with explicit port -> host (port stripped)" {
  run _mt_url_to_host "ssh://git@github.com:22/foo/bar.git"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com" ]
}

@test "to_host: https URL -> host" {
  run _mt_url_to_host "https://github.com/foo/bar.git"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com" ]
}

@test "to_host: https URL gitlab -> gitlab.com" {
  run _mt_url_to_host "https://gitlab.com/x/y"
  [ "$status" -eq 0 ]
  [ "$output" = "gitlab.com" ]
}

@test "to_host: SSH deep path -> host" {
  run _mt_url_to_host "git@gitlab.com:group/sub/repo.git"
  [ "$status" -eq 0 ]
  [ "$output" = "gitlab.com" ]
}

@test "to_host: ssh_config alias preserved verbatim (no dot)" {
  run _mt_url_to_host "failmode:owner/repo"
  [ "$status" -eq 0 ]
  [ "$output" = "failmode" ]
}

@test "to_host: custom user@host -> host (user stripped)" {
  run _mt_url_to_host "mike@codeberg.org:foo/bar"
  [ "$status" -eq 0 ]
  [ "$output" = "codeberg.org" ]
}

@test "to_host: SSH with identity -> host_identity (distinct ControlMaster socket)" {
  run _mt_url_to_host "git@github.com_mbailey:mbailey/keycutter.git"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com_mbailey" ]
}

@test "to_host: bare shorthand -> default host" {
  run _mt_url_to_host "mbailey/keycutter"
  [ "$status" -eq 0 ]
  [ "$output" = "github.com" ]
}

@test "to_host: local path returns rc=1" {
  run _mt_url_to_host "/path/to/repo"
  [ "$status" -eq 1 ]
}
