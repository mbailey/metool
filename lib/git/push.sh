# Functions for mt git push command

# Push a single repository to remote
# Arguments:
#   $1 - repository spec (e.g., "user/repo")
#   $2 - target name (directory name / symlink)
#   $3 - force push (true/false)
#   $4 - push all branches (true/false)
# Returns:
#   0 on success, 1 on failure
# Output:
#   Status string via STATUS: line
_mt_git_push_repo() {
  local repo_spec="${1:?repository spec required}"
  local target_name="${2:?target name required}"
  local force="${3:-false}"
  local push_all="${4:-false}"

  # Extract repository URL (ignore version for push)
  local repo_url
  if [[ "$repo_spec" =~ @ ]]; then
    repo_url="${repo_spec%%@*}"
  else
    repo_url="$repo_spec"
  fi

  # Get the canonical repository path
  local git_repo_url git_repo_path
  git_repo_url="$(_mt_repo_url "$repo_url")"
  git_repo_path="$(_mt_repo_dir "$git_repo_url")"

  if [[ -z "$git_repo_path" ]]; then
    _mt_error "Failed to determine repository path for: $repo_url"
    echo "STATUS:error"
    return 1
  fi

  # Check if repository exists
  if [[ ! -d "$git_repo_path/.git" ]]; then
    _mt_error "Repository not found: $git_repo_path"
    echo "STATUS:not-found"
    return 1
  fi

  # Check for uncommitted changes
  if ! _mt_git_is_clean "$git_repo_path"; then
    _mt_warning "Skipping $repo_spec - has uncommitted changes"
    echo "STATUS:dirty"
    return 0
  fi

  # Check repository status
  local repo_status
  repo_status=$(_mt_git_repo_status "$git_repo_path")

  case "$repo_status" in
    current)
      echo "[INFO] Nothing to push - already up to date" >&2
      echo "STATUS:current"
      return 0
      ;;
    behind)
      _mt_warning "Repository is behind remote - pull first"
      echo "STATUS:behind"
      return 0
      ;;
    ahead)
      # Good to push
      ;;
    diverged)
      if [[ "$force" == "true" ]]; then
        _mt_warning "Repository has diverged - force pushing"
      else
        _mt_warning "Repository has diverged from remote - use --force to push anyway"
        echo "STATUS:diverged"
        return 0
      fi
      ;;
    detached)
      _mt_warning "Repository is in detached HEAD state - cannot push"
      echo "STATUS:detached"
      return 0
      ;;
    no-remote)
      _mt_warning "Repository has no remote tracking branch"
      echo "STATUS:no-remote"
      return 0
      ;;
    *)
      _mt_error "Unknown repository status: $repo_status"
      echo "STATUS:error"
      return 1
      ;;
  esac

  # Build push arguments
  local push_args=("--quiet")
  [[ "$force" == "true" ]] && push_args+=("--force-with-lease")

  if [[ "$push_all" == "true" ]]; then
    # Push all branches
    echo "[INFO] Pushing all branches to origin..." >&2
    if git -C "$git_repo_path" push "${push_args[@]}" --all origin 2>/dev/null; then
      echo "[INFO] Successfully pushed all branches" >&2
      echo "STATUS:pushed-all"
      return 0
    else
      _mt_error "Failed to push all branches to origin"
      echo "STATUS:error"
      return 1
    fi
  else
    # Push current branch only
    local current_branch
    current_branch=$(git -C "$git_repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ -z "$current_branch" || "$current_branch" == "HEAD" ]]; then
      _mt_warning "Cannot determine current branch"
      echo "STATUS:error"
      return 1
    fi

    echo "[INFO] Pushing $current_branch to origin..." >&2
    if git -C "$git_repo_path" push "${push_args[@]}" origin "$current_branch" 2>/dev/null; then
      echo "[INFO] Successfully pushed" >&2
      echo "STATUS:pushed"
      return 0
    else
      _mt_error "Failed to push to origin"
      echo "STATUS:error"
      return 1
    fi
  fi
}

# Process repositories from a manifest file for push
# Arguments:
#   $1 - repos file path
#   $2 - working directory
#   $3 - force push (true/false)
#   $4 - push all branches (true/false)
# Returns:
#   0 on success (even if some repos failed)
#   1 on fatal error
_mt_git_push_process_repos() {
  local repos_file="${1:?repos file required}"
  local work_dir="${2:?working directory required}"
  local force="${3:-false}"
  local push_all="${4:-false}"

  # Track results for summary
  local -a push_results=()

  _mt_info "Analyzing repositories..."

  # Count repos
  local repo_count=0
  while IFS=$'\t' read -r repo target; do
    ((repo_count++))
  done < <(_mt_git_manifest_parse "$repos_file")

  _mt_info "Found $repo_count repositories to check"

  echo
  _mt_info "Checking repositories for changes to push"
  echo

  # Process each repository
  while IFS=$'\t' read -r repo target; do
    # Get the canonical repository path
    local repo_url
    if [[ "$repo" =~ @ ]]; then
      repo_url="${repo%%@*}"
    else
      repo_url="$repo"
    fi

    local git_repo_url git_repo_path
    git_repo_url="$(_mt_repo_url "$repo_url")"
    git_repo_path="$(_mt_repo_dir "$git_repo_url")"

    # Skip if repository doesn't exist
    if [[ ! -d "$git_repo_path/.git" ]]; then
      _mt_warning "Skipping $repo - not cloned"
      push_results+=("${repo}\t-\tnot-cloned\t${target}")
      continue
    fi

    _mt_info "Checking: $repo"

    local status push_output
    push_output=$(_mt_git_push_repo "$repo" "$target" "$force" "$push_all" 2>&1)

    # Extract status from output
    status=$(echo "$push_output" | command grep "^STATUS:" | cut -d: -f2)
    # Show info messages (everything except STATUS line)
    echo "$push_output" | command grep -v "^STATUS:"

    # Get current ref for display
    local ref_display
    ref_display=$(_mt_git_current_ref "$git_repo_path")
    [[ -z "$ref_display" ]] && ref_display="-"

    # Store result for summary
    push_results+=("${repo}\t${ref_display}\t${status}\t${target}")
  done < <(_mt_git_manifest_parse "$repos_file")

  # Output summary
  _mt_git_summary "Push Summary:" "${push_results[@]}"

  return 0
}

# Main push function
_mt_git_push() {
  local repos_file=""
  local work_dir=""
  local dry_run=false
  local force=false
  local push_all="${MT_GIT_PUSH_ALL:-false}"
  local show_help=false

  # Check for help first
  for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
      show_help=true
      break
    fi
  done

  if [[ "$show_help" == "true" ]]; then
    cat << 'EOF'
Usage: mt git push [directory|file] [options]

Push local commits for git repositories defined in a .repos.txt manifest file.

File Discovery:
  When no file is specified, mt git push searches for manifest files in this order:
  - In git repositories: searches from current directory up to git root
  - Outside git repos: only checks current directory
  - Priority: .repos.txt (hidden) before repos.txt (visible)

Arguments:
  directory|file    Path to directory containing repos file or path to specific file

Options:
  -a, --all                 push all branches (default: current branch only)
  -n, --dry-run             show what would be pushed without executing
  -f, --force               force push (uses --force-with-lease for safety)
  -v, --verbose             detailed output
  -h, --help                show this help

Examples:
  mt git push                        # push current branch for all repos
  mt git push --all                  # push all branches for all repos
  mt git push ~/projects/            # push repos from .repos.txt in directory
  mt git push ~/projects/.repos.txt  # push repos from specific manifest file
  mt git push --dry-run              # preview what would be pushed

Notes:
  - Repositories with uncommitted changes are skipped
  - Repositories that are behind remote are skipped (pull first)
  - Repositories that have diverged require --force flag

Environment Variables:
  MT_PULL_FILE              override repos file name (disables auto-discovery)
  MT_GIT_PUSH_ALL           set to 'true' to push all branches by default
EOF
    return 0
  fi

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help=true
        shift
        ;;
      -a|--all)
        push_all=true
        shift
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -f|--force)
        force=true
        shift
        ;;
      -v|--verbose)
        export MT_VERBOSE=true
        shift
        ;;
      -*)
        _mt_error "Unknown option: $1"
        return 1
        ;;
      *)
        # Positional argument
        if [[ -z "$repos_file" ]]; then
          local arg="$1"

          # Check if it's a file
          if [[ -f "$arg" ]]; then
            repos_file="$(command realpath "$arg")"
            work_dir="$(dirname "$repos_file")"
          # Check if it's a directory
          elif [[ -d "$arg" ]]; then
            work_dir="$(command realpath "$arg")"
            if repos_file=$(_mt_git_manifest_find "$work_dir"); then
              work_dir="$(dirname "$repos_file")"
            else
              _mt_error "No repos.txt or .repos.txt found in directory: $arg"
              return 1
            fi
          else
            _mt_error "Path not found: $arg"
            return 1
          fi
        else
          _mt_error "Too many arguments"
          return 1
        fi
        shift
        ;;
    esac
  done

  # If no file specified, use intelligent discovery
  if [[ -z "$repos_file" ]]; then
    if repos_file=$(_mt_git_manifest_find); then
      work_dir="$(dirname "$repos_file")"
    else
      _mt_error "No repos.txt or .repos.txt found. Searched from current directory$(git rev-parse --show-toplevel 2>/dev/null && echo " up to git repository root" || echo "")"
      return 1
    fi
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
      _mt_info "No repositories to push" >&2
    else
      echo
      echo "Repositories to check for push:"
      printf "%-40s %-10s %s\n" "REPO" "STATUS" "TARGET"
      printf "%-40s %-10s %s\n" "----" "------" "------"

      while IFS=$'\t' read -r repo target; do
        # Get repo path and status
        local repo_url
        if [[ "$repo" =~ @ ]]; then
          repo_url="${repo%%@*}"
        else
          repo_url="$repo"
        fi

        local git_repo_url git_repo_path status
        git_repo_url="$(_mt_repo_url "$repo_url")"
        git_repo_path="$(_mt_repo_dir "$git_repo_url")"

        if [[ ! -d "$git_repo_path/.git" ]]; then
          status="not-cloned"
        elif ! _mt_git_is_clean "$git_repo_path"; then
          status="dirty"
        else
          status=$(_mt_git_repo_status "$git_repo_path")
        fi

        printf "%-40s %-10s %s\n" "$repo" "$status" "$target"
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
  if [[ "$push_all" == "true" ]]; then
    _mt_info "Push all branches mode enabled"
  fi
  if [[ "$force" == "true" ]]; then
    _mt_warning "Force mode enabled - will use --force-with-lease"
  fi

  local result=0
  if ! _mt_git_push_process_repos "$repos_file" "$work_dir" "$force" "$push_all"; then
    result=1
  fi

  # Return to original directory
  cd "$current_dir"
  return $result
}
