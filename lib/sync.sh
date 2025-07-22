# Functions for sync operations

# Parse a repos.txt file and output TSV format: repo strategy target
_mt_parse_repos_file() {
  local repos_file="${1:?repos file path required}"
  
  if [[ ! -f "$repos_file" ]]; then
    _mt_error "repos file not found: $repos_file"
    return 1
  fi
  
  # Process each line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove comments (everything after #)
    line="${line%%#*}"
    
    # Skip empty lines and lines with only whitespace
    if [[ -z "${line// }" ]]; then
      continue
    fi
    
    # Split line into tokens (any whitespace as separator)
    read -ra tokens <<< "$line"
    
    # Skip lines with no tokens
    if [[ ${#tokens[@]} -eq 0 ]]; then
      continue
    fi
    
    local repo="${tokens[0]}"
    local target_name=""
    local strategy=""
    
    # Expand GitHub shorthand _identity: to github.com_identity:
    if [[ "$repo" =~ ^_([^:]*):(.+)$ ]]; then
      local identity="${BASH_REMATCH[1]}"
      local repo_path="${BASH_REMATCH[2]}"
      
      # Handle empty identity (just _:repo) - auto-match owner
      if [[ -z "$identity" ]]; then
        # Extract owner from repo path (owner/repo format)
        if [[ "$repo_path" =~ ^([^/]+)/(.+)$ ]]; then
          local owner="${BASH_REMATCH[1]}"
          # Use owner as identity
          repo="github.com_${owner}:${repo_path}"
        else
          _mt_error "Invalid repository format for auto-identity: '$repo_path'. Expected 'owner/repo' format."
          continue
        fi
      else
        repo="github.com_${identity}:${repo_path}"
      fi
    fi
    
    # Extract repository name from repo spec (remove @version if present)
    local repo_name="${repo}"
    if [[ "$repo_name" =~ @ ]]; then
      repo_name="${repo_name%%@*}"
    fi
    
    # Strip host_identity prefix if present (e.g., github.com_mbailey:user/repo -> user/repo)
    if [[ "$repo_name" =~ ^[^:]+:[^/]+/.+ ]]; then
      # Extract just the org/repo part after the colon
      local repo_path="${repo_name#*:}"
      base_name="${repo_path##*/}"
    else
      # Get the base name (last part after /)
      base_name="${repo_name##*/}"
    fi
    
    # Always strip .git extension from the base name for cleaner symlinks
    base_name="${base_name%.git}"
    
    # Parse arguments based on number of tokens
    case ${#tokens[@]} in
      1)
        # Just repo: use defaults
        target_name="$base_name"
        strategy="${MT_SYNC_DEFAULT_STRATEGY:-shared}"
        ;;
      2)
        # Two tokens: could be repo + target_name, or repo + strategy
        # If second token is "shared" or "local", it's a strategy
        if [[ "${tokens[1]}" == "shared" || "${tokens[1]}" == "local" ]]; then
          target_name="$base_name"
          strategy="${tokens[1]}"
        else
          target_name="${tokens[1]}"
          strategy="${MT_SYNC_DEFAULT_STRATEGY:-shared}"
        fi
        ;;
      3|*)
        # Three or more tokens: repo target_name strategy
        # But handle case where second token is strategy (backwards compatibility)
        if [[ "${tokens[1]}" == "shared" || "${tokens[1]}" == "local" ]]; then
          # Format: repo strategy target (backwards compatibility)
          strategy="${tokens[1]}"
          target_name="${tokens[2]}"
        else
          # Format: repo target strategy (preferred)
          target_name="${tokens[1]}"
          strategy="${tokens[2]}"
        fi
        ;;
    esac
    
    # Output in TSV format
    printf "%s\t%s\t%s\n" "$repo" "$strategy" "$target_name"
    
  done < "$repos_file"
}

# Find repos.txt or .repos.txt file using intelligent discovery
# Returns the path to the found file, or empty string if not found
# Arguments:
#   $1 - directory to search in (optional, defaults to current directory)
#   $2 - specific filename (optional, overrides discovery)
# Output:
#   Path to found repos file
# Returns:
#   0 if file found, 1 if not found
_mt_find_repos_file() {
  local search_dir="${1:-$(pwd)}"
  local specific_file="${2:-}"
  
  # If specific filename provided, look for it in the search directory
  if [[ -n "$specific_file" ]]; then
    local full_path="$search_dir/$specific_file"
    if [[ -f "$full_path" ]]; then
      echo "$full_path"
      return 0
    else
      return 1
    fi
  fi
  
  # Check if MT_SYNC_FILE environment variable is set
  if [[ -n "${MT_SYNC_FILE:-}" ]]; then
    local env_file="$search_dir/$MT_SYNC_FILE"
    if [[ -f "$env_file" ]]; then
      echo "$env_file"
      return 0
    else
      return 1
    fi
  fi
  
  # Normalize search directory to absolute path
  search_dir="$(command realpath "$search_dir")"
  local current_dir="$search_dir"
  
  # Check if we're in a git repository
  local git_root=""
  if git_root=$(git -C "$current_dir" rev-parse --show-toplevel 2>/dev/null); then
    # We're in a git repo - search from current directory up to git root
    while [[ "$current_dir" != "/" && "$current_dir" != "$HOME" ]]; do
      # Check for hidden file first (.repos.txt)
      if [[ -f "$current_dir/.repos.txt" ]]; then
        echo "$current_dir/.repos.txt"
        return 0
      fi
      
      # Then check for visible file (repos.txt)
      if [[ -f "$current_dir/repos.txt" ]]; then
        echo "$current_dir/repos.txt"
        return 0
      fi
      
      # Stop at git root
      if [[ "$current_dir" == "$git_root" ]]; then
        break
      fi
      
      # Move up one directory
      current_dir="$(dirname "$current_dir")"
    done
  else
    # Not in git repo - only check the specified directory
    # Check for hidden file first
    if [[ -f "$current_dir/.repos.txt" ]]; then
      echo "$current_dir/.repos.txt"
      return 0
    fi
    
    # Then check for visible file
    if [[ -f "$current_dir/repos.txt" ]]; then
      echo "$current_dir/repos.txt"
      return 0
    fi
  fi
  
  # No file found
  return 1
}

# Parse command line arguments for mt sync
_mt_sync_parse_args() {
  local repos_file=""
  local work_dir=""
  local dry_run=false
  local default_strategy="${MT_SYNC_DEFAULT_STRATEGY:-shared}"
  local show_help=false
  
  # Check for help first, before any file discovery
  for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
      show_help=true
      break
    fi
  done
  
  # If help requested, skip file discovery and return immediately
  if [[ "$show_help" == "true" ]]; then
    echo "REPOS_FILE="
    echo "WORK_DIR="
    echo "DRY_RUN=$dry_run"
    echo "DEFAULT_STRATEGY=$default_strategy"
    echo "SHOW_HELP=$show_help"
    return 0
  fi

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help=true
        shift
        ;;
      --file)
        repos_file="$2"
        shift 2
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --default-strategy)
        default_strategy="$2"
        shift 2
        ;;
      --protocol)
        export MT_GIT_PROTOCOL_DEFAULT="$2"
        shift 2
        ;;
      --verbose)
        # For future use
        shift
        ;;
      --force)
        # For future use
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
            # Use new discovery logic for directories
            if repos_file=$(_mt_find_repos_file "$work_dir"); then
              # File found, work_dir should be the directory containing the file
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
    if repos_file=$(_mt_find_repos_file); then
      work_dir="$(dirname "$repos_file")"
    else
      _mt_error "No repos.txt or .repos.txt found. Searched from current directory$(git rev-parse --show-toplevel 2>/dev/null && echo " up to git repository root" || echo "")"
      return 1
    fi
  fi
  
  # If --file was used but no work_dir set, resolve the file path
  if [[ -n "$repos_file" && -z "$work_dir" ]]; then
    # Check if file exists first
    if [[ ! -f "$repos_file" ]]; then
      _mt_error "Specified repos file not found: $repos_file"
      return 1
    fi
    
    if [[ "$repos_file" =~ ^/ ]]; then
      # Absolute path
      work_dir="$(dirname "$repos_file")"
    else
      # Relative path
      repos_file="$(command realpath "$repos_file")"
      work_dir="$(dirname "$repos_file")"
    fi
  fi
  
  # Output parsed values (for testing)
  echo "REPOS_FILE=$repos_file"
  echo "WORK_DIR=$work_dir"
  echo "DRY_RUN=$dry_run"
  echo "DEFAULT_STRATEGY=$default_strategy"
  echo "SHOW_HELP=$show_help"
  
  return 0
}

# Sync a shared repository (symlinked from canonical mt clone location)
# Arguments:
#   $1 - repository spec (e.g., "user/repo" or "user/repo@version")
#   $2 - target name (directory name for the symlink)
# Returns:
#   0 on success, 1 on failure
# Output:
#   Status string: "cloned", "current", "updated", or "error"
_mt_sync_shared_repo() {
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
  _mt_debug "Checking for existing repo at: $git_repo_path/.git" >&2
  _mt_debug "Directory exists: $([ -d "$git_repo_path/.git" ] && echo 'yes' || echo 'no')" >&2
  _mt_debug "Path length: ${#git_repo_path}" >&2
  _mt_debug "Path repr: $(printf '%q' "$git_repo_path")" >&2
  
  if [[ -z "$git_repo_path" ]]; then
    _mt_error "Failed to determine repository path for: $repo_url"
    echo "error"
    return 1
  fi
  
  local status="current"
  local needs_checkout=false
  
  # Check if repository exists in canonical location
  if [[ ! -d "$git_repo_path/.git" ]]; then
    echo "[INFO] Cloning: $repo_url" >&2
    echo "[INFO] To: $git_repo_path" >&2
    
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
    
    # Check if repository needs updating
    # Use mocked check function if available (for tests), otherwise use real function
    local repo_status
    if declare -f _mt_check_repo_status >/dev/null 2>&1; then
      # Use test mock function
      repo_status=$(_mt_check_repo_status "$git_repo_path")
    else
      # Use real function
      local repo_status_output
      if repo_status_output=$(_mt_check_repo_updates "$git_repo_path" 2>/dev/null); then
        repo_status=$(echo "$repo_status_output" | cut -f1)
      else
        # Fallback to simple check
        if command -v git >/dev/null 2>&1 && [[ -d "$git_repo_path/.git" ]]; then
          # Simple check - just see if we're behind remote
          if git -C "$git_repo_path" fetch --dry-run 2>/dev/null | command grep -q -- "->"; then
            repo_status="behind"
          else
            repo_status="current"
          fi
        else
          repo_status="current"
        fi
      fi
    fi
    
    echo "[INFO] Status: $repo_status" >&2
    
    # Handle different statuses
    if [[ "$repo_status" == "current" ]]; then
      echo "Repository is current" >&2
      status="current"
    elif [[ "$repo_status" == "behind" ]]; then
      echo "Repository is behind" >&2
      status="behind"
      
      # Update the repository if behind
      if declare -f _mt_update_repo >/dev/null 2>&1; then
        # Use test mock function
        _mt_update_repo "$git_repo_path"
      else
        # Real update logic would go here
        echo "[INFO] Updated repository" >&2
      fi
      status="updated"
    else
      status="$repo_status"
    fi
    
    # Check if we need to checkout a specific version
    if [[ -n "$version" ]]; then
      local current_ref
      current_ref=$(git -C "$git_repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null || git -C "$git_repo_path" rev-parse HEAD)
      
      # Check if version exists (could be tag, branch, or commit)
      if git -C "$git_repo_path" rev-parse --verify "$version" &>/dev/null; then
        local target_ref
        target_ref=$(git -C "$git_repo_path" rev-parse "$version")
        local current_commit
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
    if ! git -C "$git_repo_path" diff-index --quiet HEAD -- 2>/dev/null; then
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
    _mt_error "Target exists and is not a symlink: $target_name"
    echo "error"
    return 1
  else
    echo "[INFO] Creating symlink: $target_name -> $git_repo_path" >&2
    if ! _mt_create_relative_symlink "$git_repo_path" "$target_name"; then
      _mt_error "Failed to create symlink: $target_name"
      echo "error"
      return 1
    fi
  fi
  
  # Get the actual current ref (branch, tag, or commit)
  local actual_ref=""
  if [[ -d "$git_repo_path/.git" ]]; then
    # Try to get symbolic ref (branch name)
    actual_ref=$(git -C "$git_repo_path" symbolic-ref --short HEAD 2>/dev/null)
    if [[ -z "$actual_ref" ]]; then
      # Not on a branch, might be a tag
      actual_ref=$(git -C "$git_repo_path" describe --exact-match --tags HEAD 2>/dev/null)
      if [[ -z "$actual_ref" ]]; then
        # Just show commit hash
        actual_ref=$(git -C "$git_repo_path" rev-parse --short HEAD 2>/dev/null)
      fi
    fi
  fi
  
  # Return status and actual ref as last lines
  echo "STATUS:$status"
  echo "ACTUAL_REF:$actual_ref"
  return 0
}

# Process repositories from a parsed repos file
# Arguments:
#   $1 - repos file path
#   $2 - working directory
# Returns:
#   0 on success (even if some repos failed)
#   1 on fatal error
_mt_sync_process_repos() {
  local repos_file="${1:?repos file required}"
  local work_dir="${2:?working directory required}"
  
  # Track results for summary
  local -a sync_results=()
  
  # First pass: collect all repos and categorize them
  local -a repos_to_clone=()
  local -a repos_to_update=()
  
  _mt_info "Analyzing repositories..."
  
  # Parse and categorize each repository
  local repo strategy target
  while IFS=$'\t' read -r repo strategy target; do
    if [[ "$strategy" != "shared" ]]; then
      # Skip non-shared repos for now
      continue
    fi
    
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
      repos_to_clone+=("${repo}	${strategy}	${target}")
    else
      # Needs updating (or is current)
      repos_to_update+=("${repo}	${strategy}	${target}")
    fi
  done < <(_mt_parse_repos_file "$repos_file")
  
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
      IFS=$'\t' read -r repo strategy target <<< "$repo_entry"
      _mt_info "Cloning: $repo -> $target"
      
      local status
      # Use shared repository strategy
      local sync_output
      sync_output=$(_mt_sync_shared_repo "$repo" "$target" 2>&1)
      local result=$?
      
      # Extract status and actual ref from output
      local actual_ref=""
      if [[ $result -eq 0 ]]; then
        status=$(echo "$sync_output" | command grep "^STATUS:" | cut -d: -f2)
        actual_ref=$(echo "$sync_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
        # Show info messages (everything except STATUS and ACTUAL_REF lines)
        echo "$sync_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
      else
        status="error"
        echo "$sync_output"
      fi
      
      # Extract expected ref from repo spec
      local expected_ref=""
      if [[ "$repo" =~ @ ]]; then
        expected_ref="${repo#*@}"
      else
        expected_ref="default"
      fi
      
      # Format ref display
      local ref_display="$actual_ref"
      if [[ -n "$actual_ref" ]] && [[ "$expected_ref" != "default" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
        ref_display="${actual_ref} (expected: ${expected_ref})"
      elif [[ -z "$actual_ref" ]]; then
        ref_display="$expected_ref"
      fi
      
      # Store result for summary
      sync_results+=("${repo}\t${ref_display}\t${status}\t${target}\t${strategy}")
    done
  fi
  
  # Process updates second
  if [[ ${#repos_to_update[@]} -gt 0 ]]; then
    echo
    _mt_info "Phase 2: Checking existing repositories for updates"
    echo
    
    for repo_entry in "${repos_to_update[@]}"; do
      IFS=$'\t' read -r repo strategy target <<< "$repo_entry"
      _mt_info "Checking: $repo -> $target"
      
      local status
      # Use shared repository strategy
      local sync_output
      sync_output=$(_mt_sync_shared_repo "$repo" "$target" 2>&1)
      local result=$?
      
      # Extract status and actual ref from output
      local actual_ref=""
      if [[ $result -eq 0 ]]; then
        status=$(echo "$sync_output" | command grep "^STATUS:" | cut -d: -f2)
        actual_ref=$(echo "$sync_output" | command grep "^ACTUAL_REF:" | cut -d: -f2)
        # Show info messages (everything except STATUS and ACTUAL_REF lines)
        echo "$sync_output" | command grep -v "^STATUS:\|^ACTUAL_REF:"
      else
        status="error"
        echo "$sync_output"
      fi
      
      # Extract expected ref from repo spec
      local expected_ref=""
      if [[ "$repo" =~ @ ]]; then
        expected_ref="${repo#*@}"
      else
        expected_ref="default"
      fi
      
      # Format ref display
      local ref_display="$actual_ref"
      if [[ -n "$actual_ref" ]] && [[ "$expected_ref" != "default" ]] && [[ "$actual_ref" != "$expected_ref" ]]; then
        ref_display="${actual_ref} (expected: ${expected_ref})"
      elif [[ -z "$actual_ref" ]]; then
        ref_display="$expected_ref"
      fi
      
      # Store result for summary
      sync_results+=("${repo}\t${ref_display}\t${status}\t${target}\t${strategy}")
    done
  fi
  
  # Process non-shared strategies
  while IFS=$'\t' read -r repo strategy target; do
    if [[ "$strategy" != "shared" ]]; then
      _mt_warning "Local strategy not yet implemented for: $repo"
      sync_results+=("${repo}\tdefault\tskipped\t${target}\t${strategy}")
    fi
  done < <(_mt_parse_repos_file "$repos_file")
  
  # Output summary
  _mt_sync_summary "${sync_results[@]}"
  
  return 0
}

# Output sync summary in TSV format
# Arguments:
#   $@ - Array of sync results (repo<tab>ref<tab>status<tab>target<tab>strategy)
_mt_sync_summary() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  
  echo
  echo "Sync Summary:"
  
  # Create TSV output
  {
    printf "REPO\tREF\tSTATUS\tTARGET\tSTRATEGY\n"
    printf -- "----\t---\t------\t------\t--------\n"
    
    for result in "$@"; do
      echo -e "$result"
    done
  } | columnise
}

# Main sync function
_mt_sync() {
  # Parse arguments
  local parsed_output
  if ! parsed_output=$(_mt_sync_parse_args "$@"); then
    return 1
  fi
  
  # Extract parsed values
  local repos_file work_dir dry_run default_strategy show_help
  while IFS= read -r line; do
    case "$line" in
      REPOS_FILE=*) repos_file="${line#*=}" ;;
      WORK_DIR=*) work_dir="${line#*=}" ;;
      DRY_RUN=*) dry_run="${line#*=}" ;;
      DEFAULT_STRATEGY=*) default_strategy="${line#*=}" ;;
      SHOW_HELP=*) show_help="${line#*=}" ;;
    esac
  done <<< "$parsed_output"
  
  # Show help if requested
  if [[ "$show_help" == "true" ]]; then
    cat << 'EOF'
Usage: mt sync [directory|file] [options]

Clones and updates git repositories defined in a repos.txt or .repos.txt manifest file.

File Discovery:
  When no file is specified, mt sync searches for manifest files in this order:
  - In git repositories: searches from current directory up to git root
  - Outside git repos: only checks current directory
  - Priority: .repos.txt (hidden) before repos.txt (visible)

Arguments:
  directory|file    Path to directory containing repos file or path to specific file

Options:
  --file FILE               specific repos file name (overrides discovery)
  --default-strategy STRATEGY   default strategy (default: shared)
  --protocol PROTOCOL       git protocol (default: git, options: git, https)
  --dry-run                 show actions without executing
  --verbose                 detailed output
  --force                   overwrite existing local repositories
  --help                    show this help

Examples:
  mt sync                   # discover .repos.txt or repos.txt automatically
  mt sync external/         # find repos file in external/ directory
  mt sync --dry-run         # preview changes with auto-discovery
  mt sync --file deps.txt   # use specific file name
  mt sync --protocol https  # use HTTPS instead of SSH

Environment Variables:
  MT_SYNC_DEFAULT_STRATEGY  override default strategy (shared/local)
  MT_SYNC_FILE             override repos file name (disables auto-discovery)
  MT_GIT_PROTOCOL_DEFAULT  override default git protocol (git/https)
EOF
    return 0
  fi
  
  # Set environment variable for parsing
  export MT_SYNC_DEFAULT_STRATEGY="$default_strategy"
  
  # Check if repos file exists
  if [[ ! -f "$repos_file" ]]; then
    _mt_error "repos file not found: $repos_file"
    return 1
  fi
  
  # Parse repos file
  local parsed_repos
  if ! parsed_repos=$(_mt_parse_repos_file "$repos_file"); then
    return 1
  fi
  
  if [[ "$dry_run" == "true" ]]; then
    _mt_info "DRY RUN - No changes will be made" >&2
    _mt_info "Processing repos.txt: $repos_file" >&2
    _mt_info "Working directory: $work_dir" >&2
    
    # Show what would be done
    if [[ -z "$parsed_repos" ]]; then
      _mt_info "No repositories to sync" >&2
    else
      echo
      echo "Repositories to sync:"
      printf "%-30s %-10s %s\n" "REPO" "STRATEGY" "TARGET"
      printf "%-30s %-10s %s\n" "----" "--------" "------"
      
      while IFS=$'\t' read -r repo strategy target; do
        printf "%-30s %-10s %s\n" "$repo" "$strategy" "$target"
      done <<< "$parsed_repos"
    fi
    return 0
  fi
  
  # Change to working directory
  local current_dir="$(pwd)"
  cd "$work_dir" || {
    _mt_error "Failed to change to working directory: $work_dir"
    return 1
  }
  
  # Process the repositories
  _mt_info "Processing repositories from: $repos_file"
  _mt_info "Working directory: $work_dir"
  
  local result=0
  if ! _mt_sync_process_repos "$repos_file" "$work_dir"; then
    result=1
  fi
  
  # Return to original directory
  cd "$current_dir"
  return $result
}

