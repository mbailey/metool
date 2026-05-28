# Functions for mt git pull command
#
# MT-73 refactor: _mt_git_pull_repo is now a thin wrapper over
# _mt_git_fetch_one (pure network) + _mt_git_finalize_one (mostly local,
# with a bounded second network call: `pull --rebase` only for
# `behind`/`diverged` repos). The wrapper preserves the existing public
# signature so external callers and bats tests don't notice.
#
# The split exists so the orchestrator (_mt_git_pull_process_repos) can
# fan out the bulk fetch across N workers when --parallel N > 1, while
# keeping the order-sensitive finalize step serial in manifest order.

# Pure-network: clone if missing, else git fetch --all.
# Arguments:
#   $1 - canonical repo URL (output of _mt_url_to_fetch)
#   $2 - canonical repo path (output of _mt_repo_dir)
# Returns:
#   0 on success, 1 on failure. stderr carries human-readable [INFO]/error
#   chatter; stdout is reserved for the trailer protocol that
#   _mt_git_finalize_one emits.
_mt_git_fetch_one() {
  local git_repo_url="${1:?repo url required}"
  local git_repo_path="${2:?repo path required}"

  if [[ ! -d "$git_repo_path/.git" ]]; then
    command mkdir -p "$(dirname "$git_repo_path")" || {
      _mt_error "Failed to create directory: $(dirname "$git_repo_path")"
      return 1
    }
    if ! _mt_git_clone "$git_repo_url" "$git_repo_path"; then
      return 1
    fi
    echo "[INFO] Repository cloned successfully" >&2
    return 0
  fi

  _mt_debug "Repository exists at: $git_repo_path"
  echo "[INFO] Fetching all branches..." >&2
  if ! git -C "$git_repo_path" fetch --all --quiet 2>/dev/null; then
    _mt_debug "Failed to fetch from remote (may be offline or no remote configured)"
  fi
  return 0
}

# Mostly local + bounded network: derive status, pull --rebase if
# behind/diverged, version checkout, symlink. Emits the STATUS:/ACTUAL_REF:
# trailer on stdout (the contract _mt_git_pull_process_repos parses).
#
# Arguments:
#   $1 - canonical repo URL
#   $2 - canonical repo path
#   $3 - target symlink name (relative to current dir)
#   $4 - optional pinned version (tag/branch/commit)
#   $5 - rebase flag (true/false)
#   $6 - just-cloned flag (true/false) -- skips the status check; treats
#        the repo as newly cloned and only performs version checkout +
#        symlink.
_mt_git_finalize_one() {
  local git_repo_url="${1:?repo url required}"
  local git_repo_path="${2:?repo path required}"
  local target_name="${3:?target name required}"
  local version="${4:-}"
  local do_rebase="${5:-false}"
  local just_cloned="${6:-false}"

  local status="current"
  local needs_checkout=false

  if [[ "$just_cloned" == "true" ]]; then
    status="cloned"
    needs_checkout=true
  else
    local repo_status
    repo_status=$(_mt_git_repo_status "$git_repo_path")
    echo "[INFO] Status: $repo_status" >&2

    case "$repo_status" in
      current)
        echo "Repository is current" >&2
        status="current"
        ;;
      behind)
        echo "Repository is behind" >&2
        local current_branch
        current_branch=$(git -C "$git_repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
          if git -C "$git_repo_path" pull --rebase --quiet origin "$current_branch" 2>/dev/null; then
            echo "[INFO] Updated repository" >&2
            status="updated"
          else
            _mt_error "Failed to pull updates for $git_repo_path"
            echo "STATUS:error"
            echo "ACTUAL_REF:"
            return 1
          fi
        else
          _mt_debug "Repository is in detached HEAD state, skipping pull"
          status="detached"
        fi
        ;;
      ahead)
        echo "Repository is ahead of remote" >&2
        status="ahead"
        ;;
      diverged)
        echo "Repository has diverged from remote" >&2
        if [[ "$do_rebase" == "true" ]]; then
          local current_branch
          current_branch=$(git -C "$git_repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
          if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
            echo "[INFO] Attempting rebase..." >&2
            if git -C "$git_repo_path" pull --rebase --quiet origin "$current_branch" 2>/dev/null; then
              echo "[INFO] Rebased successfully" >&2
              status="rebased"
            else
              _mt_error "Rebase failed - resolve conflicts manually in $git_repo_path"
              git -C "$git_repo_path" rebase --abort 2>/dev/null || true
              status="rebase-failed"
            fi
          else
            _mt_debug "Repository is in detached HEAD state, cannot rebase"
            status="diverged"
          fi
        else
          status="diverged"
        fi
        ;;
      detached)
        echo "Repository is in detached HEAD state" >&2
        status="detached"
        ;;
      no-remote)
        echo "Repository has no remote tracking branch" >&2
        status="no-remote"
        ;;
      *)
        status="$repo_status"
        ;;
    esac

    if [[ -n "$version" ]]; then
      if git -C "$git_repo_path" rev-parse --verify "$version" &>/dev/null; then
        local target_ref current_commit
        target_ref=$(git -C "$git_repo_path" rev-parse "$version")
        current_commit=$(git -C "$git_repo_path" rev-parse HEAD)
        if [[ "$target_ref" != "$current_commit" ]]; then
          needs_checkout=true
        fi
      else
        _mt_error "Version not found in repository: $version"
        echo "error"
        return 1
      fi
    fi
  fi

  if [[ -n "$version" ]] && [[ "$needs_checkout" == "true" ]]; then
    echo "[INFO] Checkout: $version" >&2
    if ! _mt_git_is_clean "$git_repo_path"; then
      _mt_error "Cannot checkout version - repository has uncommitted changes: $git_repo_path"
      echo "error"
      return 1
    fi
    if ! git -C "$git_repo_path" checkout "$version" --quiet; then
      _mt_error "Failed to checkout version: $version"
      echo "error"
      return 1
    fi
  fi

  # Create or verify symlink
  if [[ -L "$target_name" ]]; then
    local existing_target
    existing_target="$(readlink -f "$target_name" 2>/dev/null || true)"
    local normalized_existing normalized_expected
    normalized_existing="$(command realpath "$existing_target" 2>/dev/null || echo "$existing_target")"
    normalized_expected="$(command realpath "$git_repo_path" 2>/dev/null || echo "$git_repo_path")"
    if [[ "$normalized_existing" == "$normalized_expected" ]]; then
      _mt_debug "Symlink already exists and is correct: $target_name -> $git_repo_path"
    else
      echo "[INFO] Symlink conflict: $target_name -> $existing_target" >&2
      _mt_info "Expected: $git_repo_path"
      echo "error"
      return 1
    fi
  elif [[ -e "$target_name" ]]; then
    local existing_path target_real
    existing_path="$(command realpath "$target_name" 2>/dev/null || echo "$target_name")"
    target_real="$(command realpath "$git_repo_path" 2>/dev/null || echo "$git_repo_path")"
    if [[ "$existing_path" == "$target_real" ]]; then
      _mt_debug "Skipping symlink creation: $target_name and $git_repo_path are the same"
    else
      _mt_error "Target exists and is not a symlink: $target_name"
      echo "error"
      return 1
    fi
  else
    echo "[INFO] Creating symlink: $target_name -> $git_repo_path" >&2
    if ! _mt_create_relative_symlink "$git_repo_path" "$target_name"; then
      _mt_error "Failed to create symlink: $target_name"
      echo "error"
      return 1
    fi
  fi

  local actual_ref
  actual_ref=$(_mt_git_current_ref "$git_repo_path")
  echo "STATUS:$status"
  echo "ACTUAL_REF:$actual_ref"
  return 0
}

# Pull a single repository (fetch and pull from remote)
# Arguments:
#   $1 - repository spec (e.g., "user/repo" or "user/repo@version")
#   $2 - target name (directory name for the symlink)
#   $3 - rebase flag (true/false, optional, defaults to false)
# Returns:
#   0 on success, 1 on failure
# Output:
#   Status string via STATUS: and ACTUAL_REF: lines
_mt_git_pull_repo() {
  local repo_spec="${1:?repository spec required}"
  local target_name="${2:?target name required}"
  local do_rebase="${3:-false}"

  local repo_url version=""
  if [[ "$repo_spec" =~ @ ]]; then
    repo_url="${repo_spec%%@*}"
    version="${repo_spec#*@}"
  else
    repo_url="$repo_spec"
  fi

  local git_repo_url git_repo_path
  git_repo_url="$(_mt_url_to_fetch "$repo_url")"
  _mt_debug "Resolved URL: $git_repo_url" >&2
  git_repo_path="$(_mt_repo_dir "$git_repo_url")"
  _mt_debug "Resolved path: $git_repo_path" >&2

  if [[ -z "$git_repo_path" ]]; then
    _mt_error "Failed to determine repository path for: $repo_url"
    echo "error"
    return 1
  fi

  local just_cloned=false
  if [[ ! -d "$git_repo_path/.git" ]]; then
    just_cloned=true
  fi

  if ! _mt_git_fetch_one "$git_repo_url" "$git_repo_path"; then
    echo "error"
    return 1
  fi

  _mt_git_finalize_one "$git_repo_url" "$git_repo_path" "$target_name" \
    "$version" "$do_rebase" "$just_cloned"
}

# Run the parallel pre-warm + fetch wave.
# Arguments:
#   $1 - tmpdir for output capture
#   $2 - max concurrent jobs (>= 2)
#   $3 - name of an array variable holding "url<TAB>path<TAB>slug" entries
# Returns:
#   0 always (per-repo rc lives in $tmpdir/<slug>.rc)
_mt_git_pull_parallel_fetch_wave() {
  local tmpdir="${1:?tmpdir required}"
  local max_jobs="${2:?max jobs required}"
  local -n _wave_entries=$3

  # Pre-warm pass: one fetch per unique host (serial) to establish
  # SSH ControlMaster master sockets before the parallel wave races for
  # them. Acceptance bar is "auth completed", not "fetch succeeded" --
  # ControlMaster opens the master socket on a successful auth handshake
  # even if the underlying git fetch then errors. A pre-warm failure is
  # logged but does not abort the parallel pass; each repo will succeed
  # or fail individually.
  local US=$'\x1f'
  local -A seen_hosts=()
  local entry url path slug host resolved_url
  for entry in "${_wave_entries[@]}"; do
    IFS="$US" read -r url path slug <<< "$entry"
    # MT-76: resolve `insteadOf` rewrites before extracting the host, so
    # we pre-warm the host that fetches will actually contact (not the
    # raw manifest URL, which git may rewrite via url.<base>.insteadOf
    # at fetch time). `git ls-remote --get-url` applies the rewrites
    # without making any network call -- it's pure config lookup.
    resolved_url=$(git ls-remote --get-url "$url" 2>/dev/null) || resolved_url="$url"
    [[ -z "$resolved_url" ]] && resolved_url="$url"
    host=$(_mt_url_to_host "$resolved_url" 2>/dev/null) || continue
    [[ -z "$host" ]] && continue
    if [[ -z "${seen_hosts[$host]:-}" ]]; then
      seen_hosts[$host]=1
      _mt_debug "Pre-warming SSH ControlMaster for host: $host (resolved from: $url)"
      GIT_TERMINAL_PROMPT=0 _mt_git_fetch_one "$url" "$path" \
        >/dev/null 2>>"$tmpdir/prewarm.err" || \
        _mt_debug "Pre-warm fetch for $host failed; parallel pass will proceed"
    fi
  done

  # Parallel fetch wave. `wait -n` requires bash 4.3+. Caller has already
  # gated on that. Disable errexit around the wait loop -- a non-zero
  # worker exit must NOT abort the orchestrator (per-repo errors are
  # reported individually in the finalize phase).
  local active=0
  local prev_errexit=0
  [[ $- == *e* ]] && prev_errexit=1
  set +e

  for entry in "${_wave_entries[@]}"; do
    while (( active >= max_jobs )); do
      wait -n 2>/dev/null
      ((active--))
    done
    IFS="$US" read -r url path slug <<< "$entry"
    (
      export GIT_TERMINAL_PROMPT=0
      _mt_git_fetch_one "$url" "$path" \
        >"$tmpdir/$slug.out" 2>"$tmpdir/$slug.err"
      echo $? >"$tmpdir/$slug.rc"
    ) &
    ((active++))
  done
  wait

  (( prev_errexit == 1 )) && set -e
  return 0
}

# Process repositories from a manifest file for pull
# Arguments:
#   $1 - repos file path
#   $2 - working directory
#   $3 - quick mode (true/false)
#   $4 - rebase mode (true/false)
#   $5 - parallel job count (>= 1, default 1 = off / serial)
# Returns:
#   0 on success (even if some repos failed)
#   1 on fatal error
_mt_git_pull_process_repos() {
  local repos_file="${1:?repos file required}"
  local work_dir="${2:?working directory required}"
  local quick="${3:-false}"
  local do_rebase="${4:-false}"
  local parallel="${5:-1}"

  # Bash 4.3+ guard for the parallel codepath. `wait -n` (which the
  # orchestrator depends on) was introduced in bash 4.3 (2014). Degrade
  # to serial rather than try to emulate it.
  if (( parallel > 1 )); then
    if (( BASH_VERSINFO[0] < 4 )) || \
       { (( BASH_VERSINFO[0] == 4 )) && (( BASH_VERSINFO[1] < 3 )); }; then
      _mt_warning "--parallel requires bash 4.3+ (have ${BASH_VERSION}); falling back to serial"
      parallel=1
    fi
  fi

  local -a pull_results=()
  local -a diverged_repos=()
  local -a repos_to_clone=()
  local -a repos_to_update=()

  _mt_info "Analyzing repositories..."

  local repo target
  while IFS=$'\t' read -r repo target; do
    local repo_url version=""
    if [[ "$repo" =~ @ ]]; then
      repo_url="${repo%%@*}"
      version="${repo#*@}"
    else
      repo_url="$repo"
    fi

    local git_repo_url git_repo_path
    git_repo_url="$(_mt_url_to_fetch "$repo_url")"
    git_repo_path="$(_mt_repo_dir "$git_repo_url")"

    if [[ ! -d "$git_repo_path/.git" ]]; then
      repos_to_clone+=("${repo}	${target}")
    else
      repos_to_update+=("${repo}	${target}")
    fi
  done < <(_mt_git_manifest_parse "$repos_file")

  local total_repos=$((${#repos_to_clone[@]} + ${#repos_to_update[@]}))
  if [[ ${#repos_to_clone[@]} -gt 0 ]]; then
    _mt_info "Found ${#repos_to_clone[@]} repositories to clone and ${#repos_to_update[@]} to check for updates"
  else
    _mt_info "Found $total_repos repositories to check for updates"
  fi

  # ------------------------------------------------------------------
  # Parallel three-phase orchestrator (only when parallel > 1).
  # ------------------------------------------------------------------
  if (( parallel > 1 )); then
    local -a all_entries=()
    # Records use ASCII Unit Separator (0x1F) between fields, not \t, so
    # that empty middle fields (notably `version`) survive `read` --
    # whitespace IFS collapses consecutive delimiters and would silently
    # shift later fields into earlier slots.
    local US=$'\x1f'
    local -a all_specs=()           # one US-separated record per repo (manifest order)
    local -a all_just_cloned=()     # parallel array of true/false

    # Build the unified list: clones first, then updates -- matches the
    # serial path's clones-first-then-updates ordering so pull_results
    # stays manifest-ordered within each phase (SC2).
    local entry repo_url version git_repo_url git_repo_path slug just_cloned
    local _all_input=("${repos_to_clone[@]}")
    if [[ "$quick" != "true" ]]; then
      _all_input+=("${repos_to_update[@]}")
    fi

    for entry in "${_all_input[@]}"; do
      IFS=$'\t' read -r repo target <<< "$entry"
      repo_url="${repo%%@*}"
      version=""
      [[ "$repo" =~ @ ]] && version="${repo#*@}"
      git_repo_url="$(_mt_url_to_fetch "$repo_url")"
      git_repo_path="$(_mt_repo_dir "$git_repo_url")"
      # Stable filesystem-safe slug for capture files. The index is
      # appended so two repos that differ only in case (or in characters
      # that get squashed) don't collide.
      slug="$(printf '%05d_%s' "${#all_entries[@]}" "${repo//[^A-Za-z0-9._-]/_}")"
      just_cloned=false
      [[ ! -d "$git_repo_path/.git" ]] && just_cloned=true
      all_entries+=("${git_repo_url}${US}${git_repo_path}${US}${slug}")
      all_specs+=("${repo}${US}${target}${US}${git_repo_url}${US}${git_repo_path}${US}${version}${US}${slug}")
      all_just_cloned+=("$just_cloned")
    done

    if (( ${#all_entries[@]} > 0 )); then
      # Subshell scope for the trap so we don't clobber any caller's
      # EXIT trap. tmpdir path returns via captured stdout.
      local tmpdir
      tmpdir=$(
        set +e
        td="$(mktemp -d -t mt-git-pull.XXXXXX)" || exit 1
        trap 'rm -rf "$td"' EXIT INT TERM
        _mt_git_pull_parallel_fetch_wave "$td" "$parallel" all_entries >&2
        # Move the tmpdir out of the subshell's trap by renaming, then echo
        # the new path. The original would be reaped on EXIT otherwise.
        keep="${td}.keep"
        mv "$td" "$keep" 2>/dev/null && trap - EXIT INT TERM
        echo "$keep"
      )

      if [[ -z "$tmpdir" || ! -d "$tmpdir" ]]; then
        _mt_error "Parallel fetch wave failed to produce capture dir; aborting"
        return 1
      fi
      # Reap the captured tmpdir on EXIT of THIS function-shell. The
      # parallel sub-shell renamed it out from under its own trap.
      trap 'rm -rf "$tmpdir"' RETURN

      # Phase C: serial finalize in manifest (clones-first-then-updates) order.
      if (( ${#repos_to_clone[@]} > 0 )); then
        echo
        _mt_info "Phase 1: Cloning new repositories"
        echo
      fi
      local clone_count=${#repos_to_clone[@]}
      local emitted_phase2=false
      local errors_list=()
      local i=0
      while (( i < ${#all_specs[@]} )); do
        local spec="${all_specs[$i]}"
        IFS="$US" read -r repo target gurl gpath ver slug <<< "$spec"
        local in_update_phase=true
        if (( i < clone_count )); then
          in_update_phase=false
          _mt_info "Cloning: $repo -> $target"
        else
          if [[ "$emitted_phase2" == "false" ]]; then
            echo
            _mt_info "Phase 2: Checking existing repositories for updates"
            echo
            emitted_phase2=true
          fi
          _mt_info "Checking: $repo -> $target"
        fi

        # Replay captured fetch output for this repo.
        [[ -s "$tmpdir/$slug.out" ]] && command cat "$tmpdir/$slug.out"
        [[ -s "$tmpdir/$slug.err" ]] && command cat "$tmpdir/$slug.err" >&2
        local fetch_rc=0
        [[ -r "$tmpdir/$slug.rc" ]] && fetch_rc=$(<"$tmpdir/$slug.rc")

        local status actual_ref="" finalize_output result
        if (( fetch_rc != 0 )); then
          status="error"
          # First non-blank line of stderr as the error summary.
          local err_first=""
          if [[ -s "$tmpdir/$slug.err" ]]; then
            err_first=$(command grep -m1 -v '^[[:space:]]*$' "$tmpdir/$slug.err" 2>/dev/null)
          fi
          [[ -z "$err_first" ]] && err_first="fetch failed (rc=$fetch_rc)"
          errors_list+=("${target}	${err_first}")
        else
          local jc="${all_just_cloned[$i]}"
          finalize_output=$(_mt_git_finalize_one \
            "$gurl" "$gpath" "$target" "$ver" "$do_rebase" "$jc" 2>&1)
          result=$?
          if (( result == 0 )); then
            status=$(echo "$finalize_output" | command grep "^STATUS:" | cut -d: -f2)
            actual_ref=$(echo "$finalize_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
            echo "$finalize_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
          else
            status="error"
            echo "$finalize_output"
            local err_first
            err_first=$(echo "$finalize_output" | command grep -m1 -v '^[[:space:]]*$' 2>/dev/null)
            [[ -z "$err_first" ]] && err_first="finalize failed (rc=$result)"
            errors_list+=("${target}	${err_first}")
          fi
        fi

        if [[ "$status" == "diverged" ]] && [[ "$in_update_phase" == "true" ]]; then
          diverged_repos+=("$target")
        fi

        local ref_display="$actual_ref"
        if [[ "$repo" =~ @ ]]; then
          local expected_ref="${repo#*@}"
          if [[ -n "$actual_ref" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
            ref_display="${actual_ref} (expected: ${expected_ref})"
          fi
        fi
        [[ -z "$ref_display" ]] && ref_display="default"

        pull_results+=("${repo}\t${ref_display}\t${status}\t${target}")
        ((i++))
      done

      # Quick-mode symlink-only pass for repos_to_update (mirrors the
      # serial branch below).
      if [[ "$quick" == "true" ]] && (( ${#repos_to_update[@]} > 0 )); then
        echo
        _mt_info "Phase 2: Verifying symlinks for existing repositories (quick mode)"
        echo
        _mt_git_pull_symlink_only repos_to_update pull_results
      fi

      _mt_git_summary "Pull Summary:" "${pull_results[@]}"

      if (( ${#errors_list[@]} > 0 )); then
        echo
        echo "Errors:"
        local err
        for err in "${errors_list[@]}"; do
          IFS=$'\t' read -r etarget emsg <<< "$err"
          printf "  %s: %s\n" "$etarget" "$emsg"
        done
      fi

      if [[ ${#diverged_repos[@]} -gt 0 ]] && [[ "$do_rebase" != "true" ]]; then
        echo
        _mt_info "Tip: ${#diverged_repos[@]} repo(s) have diverged. Run with --rebase to sync them:"
        echo "  mt git pull --rebase"
      fi
      return 0
    fi
  fi

  # ------------------------------------------------------------------
  # Default serial path -- byte-identical to pre-MT-73 behaviour.
  # ------------------------------------------------------------------

  if [[ ${#repos_to_clone[@]} -gt 0 ]]; then
    echo
    _mt_info "Phase 1: Cloning new repositories"
    echo

    for repo_entry in "${repos_to_clone[@]}"; do
      IFS=$'\t' read -r repo target <<< "$repo_entry"
      _mt_info "Cloning: $repo -> $target"

      local status pull_output actual_ref=""
      pull_output=$(_mt_git_pull_repo "$repo" "$target" "$do_rebase" 2>&1)
      local result=$?

      if [[ $result -eq 0 ]]; then
        status=$(echo "$pull_output" | command grep "^STATUS:" | cut -d: -f2)
        actual_ref=$(echo "$pull_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
        echo "$pull_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
      else
        status="error"
        echo "$pull_output"
      fi

      local ref_display="$actual_ref"
      if [[ "$repo" =~ @ ]]; then
        local expected_ref="${repo#*@}"
        if [[ -n "$actual_ref" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
          ref_display="${actual_ref} (expected: ${expected_ref})"
        fi
      fi
      [[ -z "$ref_display" ]] && ref_display="default"

      pull_results+=("${repo}\t${ref_display}\t${status}\t${target}")
    done
  fi

  if [[ ${#repos_to_update[@]} -gt 0 ]] && [[ "$quick" != "true" ]]; then
    echo
    _mt_info "Phase 2: Checking existing repositories for updates"
    echo

    for repo_entry in "${repos_to_update[@]}"; do
      IFS=$'\t' read -r repo target <<< "$repo_entry"
      _mt_info "Checking: $repo -> $target"

      local status pull_output actual_ref=""
      pull_output=$(_mt_git_pull_repo "$repo" "$target" "$do_rebase" 2>&1)
      local result=$?

      if [[ $result -eq 0 ]]; then
        status=$(echo "$pull_output" | command grep "^STATUS:" | cut -d: -f2)
        actual_ref=$(echo "$pull_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
        echo "$pull_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
      else
        status="error"
        echo "$pull_output"
      fi

      if [[ "$status" == "diverged" ]]; then
        diverged_repos+=("$target")
      fi

      local ref_display="$actual_ref"
      if [[ "$repo" =~ @ ]]; then
        local expected_ref="${repo#*@}"
        if [[ -n "$actual_ref" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
          ref_display="${actual_ref} (expected: ${expected_ref})"
        fi
      fi
      [[ -z "$ref_display" ]] && ref_display="default"

      pull_results+=("${repo}\t${ref_display}\t${status}\t${target}")
    done
  elif [[ ${#repos_to_update[@]} -gt 0 ]] && [[ "$quick" == "true" ]]; then
    echo
    _mt_info "Phase 2: Verifying symlinks for existing repositories (quick mode)"
    echo
    _mt_git_pull_symlink_only repos_to_update pull_results
  fi

  _mt_git_summary "Pull Summary:" "${pull_results[@]}"

  if [[ ${#diverged_repos[@]} -gt 0 ]] && [[ "$do_rebase" != "true" ]]; then
    echo
    _mt_info "Tip: ${#diverged_repos[@]} repo(s) have diverged. Run with --rebase to sync them:"
    echo "  mt git pull --rebase"
  fi

  return 0
}

# Quick-mode symlink-only pass (extracted so both serial and parallel
# paths share the same body).
# Arguments:
#   $1 - name of input array ("repo<TAB>target" entries)
#   $2 - name of output array (pull_results to append to)
_mt_git_pull_symlink_only() {
  local -n _so_inputs=$1
  local -n _so_results=$2

  local repo_entry repo target
  for repo_entry in "${_so_inputs[@]}"; do
    IFS=$'\t' read -r repo target <<< "$repo_entry"

    local repo_url version=""
    if [[ "$repo" =~ @ ]]; then
      repo_url="${repo%%@*}"
      version="${repo#*@}"
    else
      repo_url="$repo"
    fi

    local git_repo_url git_repo_path
    git_repo_url="$(_mt_url_to_fetch "$repo_url")"
    git_repo_path="$(_mt_repo_dir "$git_repo_url")"

    local status="linked"

    if [[ -L "$target" ]]; then
      local existing_target normalized_existing normalized_expected
      existing_target="$(readlink -f "$target" 2>/dev/null || true)"
      normalized_existing="$(command realpath "$existing_target" 2>/dev/null || echo "$existing_target")"
      normalized_expected="$(command realpath "$git_repo_path" 2>/dev/null || echo "$git_repo_path")"
      if [[ "$normalized_existing" == "$normalized_expected" ]]; then
        _mt_info "Symlink exists: $target -> $git_repo_path"
      else
        _mt_warning "Symlink points to different location: $target -> $existing_target"
        _mt_info "Expected: $git_repo_path"
        status="wrong-link"
      fi
    elif [[ -e "$target" ]]; then
      local existing_path target_real
      existing_path="$(command realpath "$target" 2>/dev/null || echo "$target")"
      target_real="$(command realpath "$git_repo_path" 2>/dev/null || echo "$git_repo_path")"
      if [[ "$existing_path" == "$target_real" ]]; then
        _mt_debug "Skipping symlink creation: $target and $git_repo_path are the same"
        status="exists"
      else
        _mt_error "Target exists and is not a symlink: $target"
        status="error"
      fi
    else
      _mt_info "Creating symlink: $target -> $git_repo_path"
      if _mt_create_relative_symlink "$git_repo_path" "$target"; then
        status="linked"
      else
        _mt_error "Failed to create symlink: $target"
        status="error"
      fi
    fi

    local ref_display="${version:-default}"
    _so_results+=("${repo}\t${ref_display}\t${status}\t${target}")
  done
}

# Main pull function
_mt_git_pull() {
  # Parse arguments
  local parsed_output
  if ! parsed_output=$(_mt_git_manifest_parse_args "$@"); then
    return 1
  fi

  # Extract parsed values
  local repos_file work_dir dry_run quick rebase show_help parallel
  while IFS= read -r line; do
    case "$line" in
      REPOS_FILE=*) repos_file="${line#*=}" ;;
      WORK_DIR=*) work_dir="${line#*=}" ;;
      DRY_RUN=*) dry_run="${line#*=}" ;;
      QUICK=*) quick="${line#*=}" ;;
      REBASE=*) rebase="${line#*=}" ;;
      SHOW_HELP=*) show_help="${line#*=}" ;;
      PARALLEL=*) parallel="${line#*=}" ;;
    esac
  done <<< "$parsed_output"

  # Show help if requested
  if [[ "$show_help" == "true" ]]; then
    cat << 'EOF'
Usage: mt git pull [directory|file] [options]

Fetch and pull updates for git repositories defined in a .repos.txt manifest file.

File Discovery:
  When no file is specified, mt git pull searches for manifest files in this order:
  - In git repositories: searches from current directory up to git root
  - Outside git repos: only checks current directory
  - Priority: .repos.txt (hidden) before repos.txt (visible)

Arguments:
  directory|file    Path to directory containing repos file or path to specific file

Options:
  -q, --quick               skip updating existing repositories
  -r, --rebase              rebase diverged repositories onto remote
  -n, --dry-run             show actions without executing
  -P, --parallel N          run N fetches concurrently (default: 1, off).
                            Requires SSH ControlMaster for multi-host manifests
                            or fetches will serialise at YubiKey/auth and may
                            generate one tap-prompt per worker. Use --parallel 1
                            (or omit) if ControlMaster is disabled.
                            MT_GIT_JOBS env var sets a default; --parallel wins.
  -p, --protocol PROTOCOL   git protocol (default: git, options: git, https)
  -v, --verbose             detailed output
  -h, --help                show this help

Examples:
  mt git pull                        # discover .repos.txt or repos.txt automatically
  mt git pull ~/projects/            # find repos file in directory
  mt git pull ~/projects/.repos.txt  # use specific manifest file
  mt git pull --quick                # only clone missing, skip updates
  mt git pull --rebase               # rebase any diverged repos
  mt git pull --dry-run              # preview changes
  mt git pull -P 8                   # 8 concurrent fetches (needs ControlMaster)

Environment Variables:
  MT_PULL_FILE              override repos file name (disables auto-discovery)
  MT_GIT_PROTOCOL_DEFAULT   override default git protocol (git/https)
  MT_GIT_JOBS               default --parallel N count (flag wins if both set)
EOF
    return 0
  fi

  # Check if repos file exists
  if [[ ! -f "$repos_file" ]]; then
    _mt_error "repos file not found: $repos_file"
    return 1
  fi

  # Parse repos file
  local parsed_repos
  if ! parsed_repos=$(_mt_git_manifest_parse "$repos_file"); then
    return 1
  fi

  if [[ "$dry_run" == "true" ]]; then
    _mt_info "DRY RUN - No changes will be made" >&2
    _mt_info "Processing repos.txt: $repos_file" >&2
    _mt_info "Working directory: $work_dir" >&2

    if [[ -z "$parsed_repos" ]]; then
      _mt_info "No repositories to pull" >&2
    else
      echo
      echo "Repositories to pull:"
      printf "%-40s %s\n" "REPO" "TARGET"
      printf "%-40s %s\n" "----" "------"

      while IFS=$'\t' read -r repo target; do
        printf "%-40s %s\n" "$repo" "$target"
      done <<< "$parsed_repos"
    fi
    return 0
  fi

  # Change to working directory
  local current_dir
  current_dir="$(pwd)"
  cd "$work_dir" || {
    _mt_error "Failed to change to working directory: $work_dir"
    return 1
  }

  # Process the repositories
  _mt_info "Processing repositories from: $repos_file"
  _mt_info "Working directory: $work_dir"
  if [[ "$quick" == "true" ]]; then
    _mt_info "Quick mode: skipping updates for existing repositories"
  fi
  if (( ${parallel:-1} > 1 )); then
    _mt_info "Parallel mode: up to ${parallel} concurrent fetches"
  fi

  local result=0
  if ! _mt_git_pull_process_repos "$repos_file" "$work_dir" "$quick" "$rebase" "${parallel:-1}"; then
    result=1
  fi

  # Return to original directory
  cd "$current_dir"
  return $result
}
