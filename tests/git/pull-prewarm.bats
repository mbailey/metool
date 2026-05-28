#!/usr/bin/env bats

# MT-80: tests for `_mt_git_pull_prewarm_hosts` and the driver wiring in
# `_mt_git_pull_parallel_fetch_wave`. The helper computes the set of
# hosts the parallel wave will actually contact -- based on each entry's
# local remote configuration, not the manifest URL.
#
# These tests build their fixtures with real `git init` / `worktree add`
# / `init --bare` invocations so we exercise the helper's repo-detection
# rule (`git -C $path rev-parse --git-dir`) and `git remote get-url`'s
# post-`insteadOf` semantics for real -- not mocked.

setup() {
  export TMPDIR=$(mktemp -d)
  export MT_ROOT="${BATS_TEST_DIRNAME}/../.."

  # Neutralise the user's global / system / xdg gitconfig so per-repo
  # local insteadOf rules below are the only rewrite source active.
  # Without this, a stray `[url].insteadOf` in Mike's ~/.gitconfig could
  # turn fixture URLs into something unexpected.
  export GIT_CONFIG_GLOBAL="${TMPDIR}/gitconfig-empty"
  export GIT_CONFIG_SYSTEM=/dev/null
  : > "$GIT_CONFIG_GLOBAL"

  # Some tests (linked worktree) need a real commit, which requires an
  # author identity. Set via env so git pulls them in even without a
  # user-scoped gitconfig.
  export GIT_AUTHOR_NAME=t
  export GIT_AUTHOR_EMAIL=t@e
  export GIT_COMMITTER_NAME=t
  export GIT_COMMITTER_EMAIL=t@e

  source "${MT_ROOT}/lib/colors.sh"
  source "${MT_ROOT}/lib/functions.sh"
  source "${MT_ROOT}/lib/git/url.sh"
  source "${MT_ROOT}/lib/git/manifest.sh"
  source "${MT_ROOT}/lib/git/common.sh"
  source "${MT_ROOT}/lib/git/pull.sh"

  _mt_log() { :; }
  _mt_info() { :; }
  _mt_error() { echo "ERROR: $*" >&2; return 1; }
  _mt_warning() { :; }
  _mt_debug() { :; }

  US=$'\x1f'
  TAB=$'\t'
}

teardown() {
  cd "${BATS_TEST_DIRNAME}"
  rm -rf "${TMPDIR}"
}

# ----------------------------------------------------------------------
# Case 1: self-mapping insteadOf rule blocks a broader host rewrite, so
# the repo stays on the bare host. This is the original MT-80 bug --
# the manifest URL is HTTPS, the global rewrite would push it to an
# SSH-identity host, but the per-repo self-map (longest prefix wins)
# leaves the URL untouched. Helper must see what the wave will see.
# ----------------------------------------------------------------------

@test "MT-80: self-mapping insteadOf -> bare host emitted" {
  export MT_GIT_PROTOCOL_DEFAULT=https
  local repo="${TMPDIR}/repo"
  git init -q "$repo"
  git -C "$repo" remote add origin https://github.com/foo/bar.git
  # Broader rewrite that, on its own, would push the URL to an
  # SSH-identity host.
  git -C "$repo" config 'url.git@github.com_foo:foo/.insteadOf' 'https://github.com/foo/'
  # Per-repo self-map: longest prefix wins, opts the repo out of the
  # broader rule.
  git -C "$repo" config 'url.https://github.com/foo/bar.git.insteadOf' 'https://github.com/foo/bar.git'

  local -a entries=("https://github.com/foo/bar.git${US}${repo}${US}slug1")
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  # Exactly one record, host field is the bare host (not the SSH alias).
  [ "${#lines[@]}" -eq 1 ]
  local host="${lines[0]%%	*}"
  [ "$host" = "github.com" ]
}

# ----------------------------------------------------------------------
# Case 2: multi-remote divergence. A repo with origin on host A and
# upstream on host B must yield both hosts, in alphabetical-by-remote-
# name order (which is `git remote`'s output order).
# ----------------------------------------------------------------------

@test "MT-80: multi-remote emits both hosts in remote-name order" {
  local repo="${TMPDIR}/repo"
  git init -q "$repo"
  git -C "$repo" remote add origin   git@github.com_mbailey:mbailey/x.git
  git -C "$repo" remote add upstream https://gitlab.example.com/upstream/x.git

  local -a entries=("git@github.com_mbailey:mbailey/x.git${US}${repo}${US}slug1")
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  # First record = origin's host; second record = upstream's host.
  local host0="${lines[0]%%	*}"
  local host1="${lines[1]%%	*}"
  [ "$host0" = "github.com_mbailey" ]
  [ "$host1" = "gitlab.example.com" ]
}

# ----------------------------------------------------------------------
# Case 3: clone-target fallback. The entry's $path does not exist as a
# repo -- helper must fall back to manifest-URL resolution via
# `git ls-remote --get-url` (MT-76 path) and emit the resulting host.
# ----------------------------------------------------------------------

@test "MT-80: clone-target falls back to manifest-URL resolution" {
  local missing="${TMPDIR}/nope"
  # $missing intentionally does not exist.
  local -a entries=("git@github.com_mbailey:mbailey/x.git${US}${missing}${US}slug1")
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  local host="${lines[0]%%	*}"
  [ "$host" = "github.com_mbailey" ]
}

# ----------------------------------------------------------------------
# Case 4: linked worktree. `$path/.git` is a FILE (gitlink pointer), not
# a directory -- the naive `[[ -d $path/.git ]]` check would reject it.
# Regression latch for that rejected sketch.
# ----------------------------------------------------------------------

@test "MT-80: linked worktree is recognised as a repo" {
  local parent="${TMPDIR}/parent"
  local wt="${TMPDIR}/wt"
  git init -q "$parent"
  git -C "$parent" remote add origin git@github.com_mbailey:mbailey/x.git
  git -C "$parent" commit --allow-empty -q -m init
  git -C "$parent" worktree add -q "$wt" 2>/dev/null
  # `$wt/.git` is a file pointer, not a directory.
  [ -f "${wt}/.git" ]

  local -a entries=("git@github.com_mbailey:mbailey/x.git${US}${wt}${US}slug1")
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  local host="${lines[0]%%	*}"
  [ "$host" = "github.com_mbailey" ]
}

# ----------------------------------------------------------------------
# Case 5: bare repo. There's no `$path/.git` at all -- `$path` itself is
# the git directory. The naive `[[ -d $path/.git ]]` check would reject
# it. Regression latch for that rejected sketch.
# ----------------------------------------------------------------------

@test "MT-80: bare repo is recognised as a repo" {
  local bare="${TMPDIR}/bare.git"
  git init --bare -q "$bare"
  git -C "$bare" remote add origin https://github.com/foo/bar.git

  local -a entries=("https://github.com/foo/bar.git${US}${bare}${US}slug1")
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  local host="${lines[0]%%	*}"
  [ "$host" = "github.com" ]
}

# ----------------------------------------------------------------------
# Case 6: cross-entry dedup. Two entries whose origins resolve to the
# same host yield exactly one record, with the first entry winning.
# ----------------------------------------------------------------------

@test "MT-80: cross-entry dedup -- shared host emitted once" {
  local repo1="${TMPDIR}/r1"
  local repo2="${TMPDIR}/r2"
  git init -q "$repo1"
  git init -q "$repo2"
  git -C "$repo1" remote add origin git@github.com_mbailey:mbailey/r1.git
  git -C "$repo2" remote add origin git@github.com_mbailey:mbailey/r2.git

  local -a entries=(
    "git@github.com_mbailey:mbailey/r1.git${US}${repo1}${US}slug1"
    "git@github.com_mbailey:mbailey/r2.git${US}${repo2}${US}slug2"
  )
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  # First entry wins: source_path should be repo1.
  local source_path="${lines[0]##*	}"
  [ "$source_path" = "$repo1" ]
}

# ----------------------------------------------------------------------
# Case 7: driver test. Stub `_mt_git_fetch_one` to record (url, path)
# args. Run the driver pattern (same loop the wave inlines) and assert
# exactly one fetch per emitted host, in manifest iteration order, with
# the per-remote `source_url` -- not the manifest URL.
#
# The input array is deliberately named `all_entries`, NOT `__pwh_entries`,
# to keep the helper's nameref from self-referencing.
# ----------------------------------------------------------------------

@test "MT-80: driver invokes _mt_git_fetch_one once per host with per-remote URL" {
  local repo1="${TMPDIR}/r1"
  local repo2="${TMPDIR}/r2"
  local repo3="${TMPDIR}/r3"
  git init -q "$repo1"
  git init -q "$repo2"
  git init -q "$repo3"
  git -C "$repo1" remote add origin git@github.com_mbailey:mbailey/x.git
  git -C "$repo2" remote add origin git@github.com_mbailey:mbailey/y.git
  git -C "$repo3" remote add origin https://gitlab.example.com/upstream/z.git

  local capture="${TMPDIR}/fetch-calls"
  : > "$capture"
  _mt_git_fetch_one() {
    printf '%s\t%s\n' "$1" "$2" >> "$capture"
    return 0
  }

  local -a all_entries=(
    "git@github.com_mbailey:mbailey/x.git${US}${repo1}${US}slug1"
    "git@github.com_mbailey:mbailey/y.git${US}${repo2}${US}slug2"
    "https://gitlab.example.com/upstream/z.git${US}${repo3}${US}slug3"
  )

  # Run the same driver loop the wave inlines (see _mt_git_pull_parallel_fetch_wave).
  while IFS="$TAB" read -r host url path; do
    GIT_TERMINAL_PROMPT=0 _mt_git_fetch_one "$url" "$path" || true
  done < <(_mt_git_pull_prewarm_hosts all_entries)

  # Exactly two records: host A from entry 1 (entry 2's dup suppressed),
  # host B from entry 3.
  run cat "$capture"
  [ "${#lines[@]}" -eq 2 ]
  # Record 1: from repo1's origin (the per-remote URL, not the manifest).
  [ "${lines[0]}" = "git@github.com_mbailey:mbailey/x.git${TAB}${repo1}" ]
  # Record 2: from repo3's origin.
  [ "${lines[1]}" = "https://gitlab.example.com/upstream/z.git${TAB}${repo3}" ]
}

# ----------------------------------------------------------------------
# Case 8: broken remote alongside a working one. A registered remote
# with an unset URL must not break helper output. Regression latch for
# the `[[ -n $u ]]` and `|| continue` guards.
# ----------------------------------------------------------------------

@test "MT-80: broken remote (unset URL) is skipped, working remote still emitted" {
  local repo="${TMPDIR}/repo"
  git init -q "$repo"
  git -C "$repo" remote add origin https://github.com/foo/bar.git
  git -C "$repo" remote add broken https://github.com/foo/baz.git
  # Leaves the remote registered but without a URL.
  git -C "$repo" config --unset remote.broken.url

  local -a entries=("https://github.com/foo/bar.git${US}${repo}${US}slug1")
  run _mt_git_pull_prewarm_hosts entries
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  local host="${lines[0]%%	*}"
  [ "$host" = "github.com" ]
}
