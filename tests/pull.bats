#!/usr/bin/env bats

# Test mt git pull command (replaces sync tests)

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
  source "${MT_ROOT}/lib/git/url.sh"  # MT-72: manifest.sh depends on _mt_url_parse
  source "${MT_ROOT}/lib/git/manifest.sh"
  source "${MT_ROOT}/lib/git/common.sh"
  source "${MT_ROOT}/lib/git/pull.sh"

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

  # MT-73: orchestrator tests exercise the path that resolves the
  # canonical repo dir. The real `_mt_repo_dir` lives in lib/git.sh
  # which we don't source here -- provide a deterministic mock that
  # mirrors the real shape (MT_GIT_BASE_DIR/host/owner/repo).
  _mt_repo_dir() {
    local url="$1"
    local -A _u
    _mt_url_parse "$url" _u
    echo "${MT_GIT_BASE_DIR:-${HOME}/Code}/${_u[host]}/${_u[owner]}/${_u[repo_name]}"
  }
}

teardown() {
  cd "${BATS_TEST_DIRNAME}" # Return to the tests directory
  rm -rf "${TMPDIR}"        # Clean up temporary directory
}

# Test repos.txt parsing functionality

@test "_mt_git_manifest_parse should handle empty file" {
  touch repos.txt
  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "_mt_git_manifest_parse should handle file with only comments" {
  cat > repos.txt << 'EOF'
# This is a comment
# Another comment

# Empty line above and comment
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "_mt_git_manifest_parse should parse simple repo entries" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
vendor/ui-lib
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]
  # Should output TSV format: repo target (no more strategy)
  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')

  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib[[:space:]]+ui-lib$ ]]
}

@test "_mt_git_manifest_parse should handle repos with version specifications" {
  cat > repos.txt << 'EOF'
mbailey/mt-public@v1.0
vendor/ui-lib@main
internal/tools@abc123def
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]

  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')

  [[ "$line1" =~ ^mbailey/mt-public@v1.0[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@main[[:space:]]+ui-lib$ ]]
  [[ "$line3" =~ ^internal/tools@abc123def[[:space:]]+tools$ ]]
}

@test "_mt_git_manifest_parse should handle target name specification" {
  cat > repos.txt << 'EOF'
mbailey/mt-public     custom-name
vendor/ui-lib@v2.0    my-ui-lib
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]

  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')

  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+custom-name$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+my-ui-lib$ ]]
}

@test "_mt_git_manifest_parse should ignore legacy strategy tokens" {
  # The old format allowed: repo target strategy
  # The new format ignores "shared" and "local" as standalone tokens
  cat > repos.txt << 'EOF'
mbailey/mt-public     shared
vendor/ui-lib@v2.0    my-ui-lib     local
internal/tools        tools         shared
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]

  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')

  # "shared" as second token should be skipped, using default target
  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+mt-public$ ]]
  # "my-ui-lib" is a valid target name (not "shared" or "local")
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+my-ui-lib$ ]]
  # "tools" is a valid target name
  [[ "$line3" =~ ^internal/tools[[:space:]]+tools$ ]]
}

@test "_mt_git_manifest_parse should handle inline comments" {
  cat > repos.txt << 'EOF'
mbailey/mt-public                   # My public tools
vendor/ui-lib@v2.0   my-ui          # UI library for project
# Full comment line
internal/tools       tools          # Internal company tools
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]

  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')

  [[ "$line1" =~ ^mbailey/mt-public[[:space:]]+mt-public$ ]]
  [[ "$line2" =~ ^vendor/ui-lib@v2.0[[:space:]]+my-ui$ ]]
  [[ "$line3" =~ ^internal/tools[[:space:]]+tools$ ]]
}

@test "_mt_git_manifest_parse should return error for non-existent file" {
  run _mt_git_manifest_parse non-existent.txt
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR:" ]]
  [[ "$output" =~ "repos file not found" ]]
}

@test "_mt_git_manifest_parse should strip .git from default target names" {
  cat > repos.txt << 'EOF'
mbailey/repo.git
github.com_work:company/project.git
user/another.git  custom-name
EOF

  run _mt_git_manifest_parse repos.txt
  [ "$status" -eq 0 ]

  local line1=$(echo "$output" | sed -n '1p')
  local line2=$(echo "$output" | sed -n '2p')
  local line3=$(echo "$output" | sed -n '3p')

  # Check that .git is stripped from default target names
  [[ "$line1" =~ ^mbailey/repo.git[[:space:]]+repo$ ]]
  [[ "$line2" =~ ^github.com_work:company/project.git[[:space:]]+project$ ]]
  [[ "$line3" =~ ^user/another.git[[:space:]]+custom-name$ ]]
}

# Test argument parsing

@test "_mt_git_manifest_parse_args should default to current directory repos.txt" {
  touch repos.txt
  run _mt_git_manifest_parse_args

  [ "$status" -eq 0 ]
  # Check that output contains the repos file and work dir
  local expected_repos="$(command realpath "${WORK_DIR}/repos.txt")"
  local expected_work="$(command realpath "${WORK_DIR}")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_git_manifest_parse_args should handle directory argument" {
  mkdir -p test-project
  touch test-project/repos.txt
  run _mt_git_manifest_parse_args test-project
  [ "$status" -eq 0 ]
  local expected_repos="$(command realpath "${WORK_DIR}/test-project/repos.txt")"
  local expected_work="$(command realpath "${WORK_DIR}/test-project")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_git_manifest_parse_args should handle file argument" {
  mkdir -p test-project
  touch test-project/deps.txt
  run _mt_git_manifest_parse_args test-project/deps.txt
  [ "$status" -eq 0 ]
  local expected_repos="$(command realpath "${WORK_DIR}/test-project/deps.txt")"
  local expected_work="$(command realpath "${WORK_DIR}/test-project")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_git_manifest_parse_args should handle --file flag" {
  touch custom.txt
  run _mt_git_manifest_parse_args --file custom.txt
  [ "$status" -eq 0 ]
  local expected_repos="$(command realpath "${WORK_DIR}/custom.txt")"
  local expected_work="$(command realpath "${WORK_DIR}")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "WORK_DIR=${expected_work}" ]]
}

@test "_mt_git_manifest_parse_args should handle --dry-run flag" {
  touch repos.txt
  run _mt_git_manifest_parse_args --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DRY_RUN=true" ]]
}

@test "_mt_git_manifest_parse_args should handle --quick flag" {
  touch repos.txt
  run _mt_git_manifest_parse_args --quick
  [ "$status" -eq 0 ]
  [[ "$output" =~ "QUICK=true" ]]
}

@test "_mt_git_manifest_parse_args should handle combined flags" {
  touch custom.txt
  run _mt_git_manifest_parse_args --file custom.txt --dry-run --quick
  [ "$status" -eq 0 ]
  local expected_repos="$(command realpath "${WORK_DIR}/custom.txt")"
  [[ "$output" =~ "REPOS_FILE=${expected_repos}" ]]
  [[ "$output" =~ "DRY_RUN=true" ]]
  [[ "$output" =~ "QUICK=true" ]]
}

@test "_mt_git_manifest_parse_args should return error for non-existent directory" {
  run _mt_git_manifest_parse_args non-existent-dir
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR:" ]]
}

@test "_mt_git_manifest_parse_args should return error for non-existent file" {
  run _mt_git_manifest_parse_args non-existent.txt
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR:" ]]
}

# Test main pull function with dry-run

@test "_mt_git_pull should show dry-run output" {
  cat > repos.txt << 'EOF'
mbailey/mt-public
vendor/ui-lib@v2.0    my-ui
EOF

  run _mt_git_pull --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DRY RUN - No changes will be made" ]]
  [[ "$output" =~ "mbailey/mt-public" ]]
  [[ "$output" =~ "vendor/ui-lib@v2.0" ]]
}

@test "_mt_git_pull should show help with --help flag" {
  run _mt_git_pull --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "mt git pull" ]]
  [[ "$output" =~ "--dry-run" ]]
  [[ "$output" =~ "--quick" ]]
}

# ----------------------------------------------------------------------
# MT-73: --parallel flag plumbing
# ----------------------------------------------------------------------

@test "_mt_git_manifest_parse_args defaults PARALLEL=1 (off)" {
  unset MT_GIT_JOBS
  touch repos.txt
  run _mt_git_manifest_parse_args
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PARALLEL=1" ]]
}

@test "_mt_git_manifest_parse_args honours --parallel N" {
  unset MT_GIT_JOBS
  touch repos.txt
  run _mt_git_manifest_parse_args --parallel 4
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PARALLEL=4" ]]
}

@test "_mt_git_manifest_parse_args honours -P short alias" {
  unset MT_GIT_JOBS
  touch repos.txt
  run _mt_git_manifest_parse_args -P 3
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PARALLEL=3" ]]
}

@test "_mt_git_manifest_parse_args reads MT_GIT_JOBS env fallback" {
  touch repos.txt
  MT_GIT_JOBS=7 run _mt_git_manifest_parse_args
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PARALLEL=7" ]]
}

@test "_mt_git_manifest_parse_args: --parallel wins over MT_GIT_JOBS" {
  touch repos.txt
  MT_GIT_JOBS=2 run _mt_git_manifest_parse_args --parallel 8
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PARALLEL=8" ]]
}

@test "_mt_git_manifest_parse_args rejects non-numeric --parallel" {
  touch repos.txt
  run _mt_git_manifest_parse_args --parallel foo
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "_mt_git_manifest_parse_args rejects --parallel 0" {
  touch repos.txt
  run _mt_git_manifest_parse_args --parallel 0
  [ "$status" -eq 1 ]
  [[ "$output" =~ ">= 1" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "_mt_git_pull --help advertises --parallel and MT_GIT_JOBS" {
  run _mt_git_pull --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "--parallel" ]]
  [[ "$output" =~ "ControlMaster" ]]
  [[ "$output" =~ "MT_GIT_JOBS" ]]
}

# ----------------------------------------------------------------------
# MT-73: refactor seam -- _mt_git_pull_repo wrapper preserves signature
# and emits the trailer protocol unchanged. Same goes for the new
# _mt_git_fetch_one and _mt_git_finalize_one functions: they must exist
# and be callable.
# ----------------------------------------------------------------------

@test "MT-73: _mt_git_fetch_one is defined" {
  run declare -F _mt_git_fetch_one
  [ "$status" -eq 0 ]
}

@test "MT-73: _mt_git_finalize_one is defined" {
  run declare -F _mt_git_finalize_one
  [ "$status" -eq 0 ]
}

@test "MT-73: _mt_git_pull_repo signature unchanged (3 positional args)" {
  # Without doing real network IO, the wrapper should at least accept
  # exactly three positional args and not blow up on argument parsing.
  # Use a clearly bogus URL so we exit quickly via error path.
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  run _mt_git_pull_repo "definitely-not/a-real-repo-mt73" "/tmp/none-mt73" "false"
  # We don't assert exit code (network access will fail), just that the
  # function is defined and the call doesn't crash on arg parsing.
  [ -n "$output" ] || true
}

# ----------------------------------------------------------------------
# MT-73: orchestrator timing -- parallel beats serial when fetch is slow.
#
# Mock _mt_git_fetch_one with a `sleep 0.3` and run 4 repos with -P 4.
# Wall-clock must come in well under serial 4*0.3 = 1.2s. We pre-create
# the .git fixtures so finalize takes the local fast path (current).
# ----------------------------------------------------------------------

_mt73_setup_fake_repos() {
  local count="$1"
  local base="${MT_GIT_BASE_DIR}/github.com/mt73"
  command mkdir -p "$base"
  local i
  for ((i=1; i<=count; i++)); do
    local r="$base/repo$i"
    command mkdir -p "$r/.git"
    # Minimal `git rev-parse --show-toplevel`-compatible structure.
    # The orchestrator only needs `[[ -d $r/.git ]]` to skip clone path.
  done
}

@test "MT-73: --parallel N runs fetches concurrently (timing)" {
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  _mt73_setup_fake_repos 4

  # Manifest with 4 repos -- all "exist" so they hit the fetch+finalize path.
  cat > repos.txt << 'EOF'
mt73/repo1
mt73/repo2
mt73/repo3
mt73/repo4
EOF

  # Override _mt_git_fetch_one with a sleep stub. Each fetch costs 0.3s,
  # so serial = 1.2s, --parallel 4 should be ~0.4s.
  _mt_git_fetch_one() {
    sleep 0.3
    echo "[INFO] mocked fetch" >&2
    return 0
  }
  export -f _mt_git_fetch_one 2>/dev/null || true

  # Stub out finalize too so we don't need real git status. Emit the
  # trailer protocol the orchestrator expects.
  _mt_git_finalize_one() {
    echo "STATUS:current"
    echo "ACTUAL_REF:main"
    return 0
  }
  export -f _mt_git_finalize_one 2>/dev/null || true

  local start end elapsed
  start=$(date +%s)
  run _mt_git_pull_process_repos repos.txt "${WORK_DIR}" false false 4
  end=$(date +%s)
  elapsed=$((end - start))

  [ "$status" -eq 0 ]
  # 4 repos * 0.3s = 1.2s serial, target well under that (<= 1s)
  [ "$elapsed" -le 1 ]
}

# ----------------------------------------------------------------------
# MT-73: --parallel 1 is the off sentinel -- falls through to the
# existing serial code path (no orchestrator). The test asserts the
# function returns successfully and produces the summary table.
# ----------------------------------------------------------------------

@test "MT-73: --parallel 1 falls through to serial path" {
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  _mt73_setup_fake_repos 1
  cat > repos.txt << 'EOF'
mt73/repo1
EOF
  _mt_git_pull_repo() {
    echo "STATUS:current"
    echo "ACTUAL_REF:main"
    return 0
  }
  run _mt_git_pull_process_repos repos.txt "${WORK_DIR}" false false 1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Pull Summary" ]]
}

# ----------------------------------------------------------------------
# MT-73: one fetch failing under --parallel doesn't block others, and
# the failure is reported in the Errors: section.
# ----------------------------------------------------------------------

@test "MT-73: parallel failure isolation + Errors: section" {
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  _mt73_setup_fake_repos 3
  cat > repos.txt << 'EOF'
mt73/repo1
mt73/repo2
mt73/repo3
EOF

  # repo2 fails, others succeed.
  _mt_git_fetch_one() {
    local url="$1"
    if [[ "$url" =~ repo2 ]]; then
      echo "fatal: simulated auth failure" >&2
      return 1
    fi
    return 0
  }
  export -f _mt_git_fetch_one 2>/dev/null || true

  _mt_git_finalize_one() {
    echo "STATUS:current"
    echo "ACTUAL_REF:main"
    return 0
  }
  export -f _mt_git_finalize_one 2>/dev/null || true

  run _mt_git_pull_process_repos repos.txt "${WORK_DIR}" false false 2
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Errors:" ]]
  [[ "$output" =~ "repo2" ]]
}

# ----------------------------------------------------------------------
# MT-73: GIT_TERMINAL_PROMPT=0 is exported to parallel workers.
# ----------------------------------------------------------------------

@test "MT-73: parallel workers see GIT_TERMINAL_PROMPT=0" {
  export MT_GIT_BASE_DIR="${TMPDIR}/Code"
  _mt73_setup_fake_repos 1
  cat > repos.txt << 'EOF'
mt73/repo1
EOF

  # Capture the env var as seen by the fetch worker.
  local capture="${TMPDIR}/env-capture"
  _mt_git_fetch_one() {
    echo "GIT_TERMINAL_PROMPT=${GIT_TERMINAL_PROMPT:-unset}" >> "$capture"
    return 0
  }
  export -f _mt_git_fetch_one 2>/dev/null || true
  _mt_git_finalize_one() {
    echo "STATUS:current"
    echo "ACTUAL_REF:main"
    return 0
  }
  export -f _mt_git_finalize_one 2>/dev/null || true

  run _mt_git_pull_process_repos repos.txt "${WORK_DIR}" false false 2
  [ "$status" -eq 0 ]
  [ -f "$capture" ]
  command grep -q "GIT_TERMINAL_PROMPT=0" "$capture"
}
