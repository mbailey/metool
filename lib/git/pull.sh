# Functions for mt git pull command

# Pull a single repository (fetch and pull from remote)
# Arguments:
#   $1 - repository spec (e.g., "user/repo" or "user/repo@version")
#   $2 - target name (directory name for the symlink)
# Returns:
#   0 on success, 1 on failure
# Output:
#   Status string via STATUS: and ACTUAL_REF: lines
_mt_git_pull_repo() {
  local repo_spec="${1:?repository spec required}"
  local target_name="${2:?target name required}"

  # Extract repository and version from spec
  local repo_url version=""
  if [[ "$repo_spec" =~ @ ]]; then
    repo_url="${repo_spec%%@*}"
    version="${repo_spec#*@}"
  else
    repo_url="$repo_spec"
  fi

  # Get the canonical repository path using existing functions
  local git_repo_url git_repo_path
  git_repo_url="$(_mt_repo_url "$repo_url")"
  _mt_debug "Resolved URL: $git_repo_url" >&2
  git_repo_path="$(_mt_repo_dir "$git_repo_url")"
  _mt_debug "Resolved path: $git_repo_path" >&2

  if [[ -z "$git_repo_path" ]]; then
    _mt_error "Failed to determine repository path for: $repo_url"
    echo "error"
    return 1
  fi

  local status="current"
  local needs_checkout=false

  # Check if repository exists in canonical location
  if [[ ! -d "$git_repo_path/.git" ]]; then
    # Ensure parent directory exists
    command mkdir -p "$(dirname "$git_repo_path")" || {
      _mt_error "Failed to create directory: $(dirname "$git_repo_path")"
      echo "error"
      return 1
    }

    # Clone the repository using the existing function
    if ! _mt_git_clone "$git_repo_url" "$git_repo_path"; then
      echo "error"
      return 1
    fi

    echo "[INFO] Repository cloned successfully" >&2
    status="cloned"
    needs_checkout=true
  else
    # Repository exists, check if it needs updating
    _mt_debug "Repository exists at: $git_repo_path"

    # Fetch all branches from remote to ensure we have latest refs
    echo "[INFO] Fetching all branches..." >&2
    if ! git -C "$git_repo_path" fetch --all --quiet 2>/dev/null; then
      _mt_debug "Failed to fetch from remote (may be offline or no remote configured)"
    fi

    # Check repository status
    local repo_status
    repo_status=$(_mt_git_repo_status "$git_repo_path")

    echo "[INFO] Status: $repo_status" >&2

    # Handle different statuses
    case "$repo_status" in
      current)
        echo "Repository is current" >&2
        status="current"
        ;;
      behind)
        echo "Repository is behind" >&2
        # Pull the latest changes with rebase
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
        status="diverged"
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

    # Check if we need to checkout a specific version
    if [[ -n "$version" ]]; then
      # Check if version exists (could be tag, branch, or commit)
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

  # Checkout specific version if needed
  if [[ -n "$version" ]] && [[ "$needs_checkout" == "true" ]]; then
    echo "[INFO] Checkout: $version" >&2

    # Check for uncommitted changes before checkout
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

    # Normalize both paths to handle symlinks in MT_GIT_BASE_DIR
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
    # Check if the existing path and target are the same
    local existing_path target_real
    existing_path="$(command realpath "$target_name" 2>/dev/null || echo "$target_name")"
    target_real="$(command realpath "$git_repo_path" 2>/dev/null || echo "$git_repo_path")"

    if [[ "$existing_path" == "$target_real" ]]; then
      # Source and destination are identical, no symlink needed
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

  # Get the actual current ref
  local actual_ref
  actual_ref=$(_mt_git_current_ref "$git_repo_path")

  # Return status and actual ref as last lines
  echo "STATUS:$status"
  echo "ACTUAL_REF:$actual_ref"
  return 0
}

# Process repositories from a manifest file for pull
# Arguments:
#   $1 - repos file path
#   $2 - working directory
#   $3 - quick mode (true/false)
# Returns:
#   0 on success (even if some repos failed)
#   1 on fatal error
_mt_git_pull_process_repos() {
  local repos_file="${1:?repos file required}"
  local work_dir="${2:?working directory required}"
  local quick="${3:-false}"

  # Track results for summary
  local -a pull_results=()

  # First pass: collect all repos and categorize them
  local -a repos_to_clone=()
  local -a repos_to_update=()

  _mt_info "Analyzing repositories..."

  # Parse and categorize each repository
  local repo target
  while IFS=$'\t' read -r repo target; do
    # Extract repository URL to check if it exists
    local repo_url version=""
    if [[ "$repo" =~ @ ]]; then
      repo_url="${repo%%@*}"
      version="${repo#*@}"
    else
      repo_url="$repo"
    fi

    # Get the canonical repository path
    local git_repo_url git_repo_path
    git_repo_url="$(_mt_repo_url "$repo_url")"
    git_repo_path="$(_mt_repo_dir "$git_repo_url")"

    # Check if repository exists
    if [[ ! -d "$git_repo_path/.git" ]]; then
      # Needs cloning
      repos_to_clone+=("${repo}	${target}")
    else
      # Needs updating (or is current)
      repos_to_update+=("${repo}	${target}")
    fi
  done < <(_mt_git_manifest_parse "$repos_file")

  # Report what we found
  local total_repos=$((${#repos_to_clone[@]} + ${#repos_to_update[@]}))
  if [[ ${#repos_to_clone[@]} -gt 0 ]]; then
    _mt_info "Found ${#repos_to_clone[@]} repositories to clone and ${#repos_to_update[@]} to check for updates"
  else
    _mt_info "Found $total_repos repositories to check for updates"
  fi

  # Process clones first (usually newly added repos)
  if [[ ${#repos_to_clone[@]} -gt 0 ]]; then
    echo
    _mt_info "Phase 1: Cloning new repositories"
    echo

    for repo_entry in "${repos_to_clone[@]}"; do
      IFS=$'\t' read -r repo target <<< "$repo_entry"
      _mt_info "Cloning: $repo -> $target"

      local status pull_output actual_ref=""
      pull_output=$(_mt_git_pull_repo "$repo" "$target" 2>&1)
      local result=$?

      # Extract status and actual ref from output
      if [[ $result -eq 0 ]]; then
        status=$(echo "$pull_output" | command grep "^STATUS:" | cut -d: -f2)
        actual_ref=$(echo "$pull_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
        # Show info messages (everything except STATUS and ACTUAL_REF lines)
        echo "$pull_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
      else
        status="error"
        echo "$pull_output"
      fi

      # Format ref display
      local ref_display="$actual_ref"
      if [[ "$repo" =~ @ ]]; then
        local expected_ref="${repo#*@}"
        if [[ -n "$actual_ref" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
          ref_display="${actual_ref} (expected: ${expected_ref})"
        fi
      fi
      [[ -z "$ref_display" ]] && ref_display="default"

      # Store result for summary
      pull_results+=("${repo}\t${ref_display}\t${status}\t${target}")
    done
  fi

  # Process updates second (unless in quick mode)
  if [[ ${#repos_to_update[@]} -gt 0 ]] && [[ "$quick" != "true" ]]; then
    echo
    _mt_info "Phase 2: Checking existing repositories for updates"
    echo

    for repo_entry in "${repos_to_update[@]}"; do
      IFS=$'\t' read -r repo target <<< "$repo_entry"
      _mt_info "Checking: $repo -> $target"

      local status pull_output actual_ref=""
      pull_output=$(_mt_git_pull_repo "$repo" "$target" 2>&1)
      local result=$?

      # Extract status and actual ref from output
      if [[ $result -eq 0 ]]; then
        status=$(echo "$pull_output" | command grep "^STATUS:" | cut -d: -f2)
        actual_ref=$(echo "$pull_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
        # Show info messages (everything except STATUS and ACTUAL_REF lines)
        echo "$pull_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
      else
        status="error"
        echo "$pull_output"
      fi

      # Format ref display
      local ref_display="$actual_ref"
      if [[ "$repo" =~ @ ]]; then
        local expected_ref="${repo#*@}"
        if [[ -n "$actual_ref" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
          ref_display="${actual_ref} (expected: ${expected_ref})"
        fi
      fi
      [[ -z "$ref_display" ]] && ref_display="default"

      # Store result for summary
      pull_results+=("${repo}\t${ref_display}\t${status}\t${target}")
    done
  elif [[ ${#repos_to_update[@]} -gt 0 ]] && [[ "$quick" == "true" ]]; then
    # In quick mode, just create/verify symlinks without updating
    echo
    _mt_info "Phase 2: Verifying symlinks for existing repositories (quick mode)"
    echo

    for repo_entry in "${repos_to_update[@]}"; do
      IFS=$'\t' read -r repo target <<< "$repo_entry"

      # Extract repository URL
      local repo_url version=""
      if [[ "$repo" =~ @ ]]; then
        repo_url="${repo%%@*}"
        version="${repo#*@}"
      else
        repo_url="$repo"
      fi

      # Get the canonical repository path
      local git_repo_url git_repo_path
      git_repo_url="$(_mt_repo_url "$repo_url")"
      git_repo_path="$(_mt_repo_dir "$git_repo_url")"

      local status="linked"

      # Create or verify symlink
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

      # Store result for summary
      local ref_display="${version:-default}"
      pull_results+=("${repo}\t${ref_display}\t${status}\t${target}")
    done
  fi

  # Output summary
  _mt_git_summary "Pull Summary:" "${pull_results[@]}"

  return 0
}

# Main pull function
_mt_git_pull() {
  # Parse arguments
  local parsed_output
  if ! parsed_output=$(_mt_git_manifest_parse_args "$@"); then
    return 1
  fi

  # Extract parsed values
  local repos_file work_dir dry_run quick show_help
  while IFS= read -r line; do
    case "$line" in
      REPOS_FILE=*) repos_file="${line#*=}" ;;
      WORK_DIR=*) work_dir="${line#*=}" ;;
      DRY_RUN=*) dry_run="${line#*=}" ;;
      QUICK=*) quick="${line#*=}" ;;
      SHOW_HELP=*) show_help="${line#*=}" ;;
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
  -n, --dry-run             show actions without executing
  -p, --protocol PROTOCOL   git protocol (default: git, options: git, https)
  -v, --verbose             detailed output
  -h, --help                show this help

Examples:
  mt git pull                        # discover .repos.txt or repos.txt automatically
  mt git pull ~/projects/            # find repos file in directory
  mt git pull ~/projects/.repos.txt  # use specific manifest file
  mt git pull --quick                # only clone missing, skip updates
  mt git pull --dry-run              # preview changes

Environment Variables:
  MT_PULL_FILE              override repos file name (disables auto-discovery)
  MT_GIT_PROTOCOL_DEFAULT   override default git protocol (git/https)
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

    # Show what would be done
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

  local result=0
  if ! _mt_git_pull_process_repos "$repos_file" "$work_dir" "$quick"; then
    result=1
  fi

  # Return to original directory
  cd "$current_dir"
  return $result
}
