# Functions for git operations

# Main git command dispatcher
_mt_git() {
  local subcommand="${1:-}"
  shift || true
  
  case "$subcommand" in
    clone)
      _mt_clone "$@"
      ;;
    repos)
      # Go directly to discover since it's the only subcommand
      _mt_repos_discover "$@"
      ;;
    sync)
      _mt_sync "$@"
      ;;
    add)
      _mt_git_add "$@"
      ;;
    trusted)
      _mt_git_trusted "$@"
      ;;
    *)
      echo "Usage: mt git <command>"
      echo ""
      echo "Commands:"
      echo "  add [REPO] [ALIAS]   Add repository to nearest .repos.txt file"
      echo "  clone URL [PATH]     Clone a git repository to a canonical location"
      echo "  repos                List git repositories"
      echo "  sync [DIR|FILE]      Sync repositories from repos.txt manifest file"
      echo "  trusted [PATH]       Check if repository is trusted or list patterns"
      echo ""
      return 1
      ;;
  esac
}

# Check if a git repository is trusted based on URL patterns
_mt_git_trusted() {
  local dir="${1:-.}"
  
  # Path to trusted patterns file
  local trust_file="${MT_ROOT}/lib/trusted-projects.txt"
  
  # If no arguments, list trusted patterns
  if [[ "$1" == "" ]] || [[ "$1" == "--list" ]] || [[ "$1" == "-l" ]]; then
    if [[ -f "$trust_file" ]]; then
      echo "Trusted repository patterns:"
      echo ""
      grep -v '^#' "$trust_file" | grep -v '^[[:space:]]*$' | while read -r pattern; do
        echo "  $pattern"
      done
    else
      _mt_error "Trust patterns file not found: $trust_file"
      return 2
    fi
    return 0
  fi
  
  # Help option
  if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    cat << EOF
Usage: mt git trusted [PATH]

Check if a git repository is trusted based on configured URL patterns

Options:
  PATH              Directory to check (default: current directory)
  -l, --list        List all trusted patterns
  -h, --help        Show this help message

Returns:
  TRUSTED           Repository matches a trusted pattern
  UNTRUSTED         Repository does not match any trusted pattern
  NOT_GIT           Directory is not a git repository
  NO_REMOTE         Repository has no remote origin

Exit codes:
  0                 Repository is trusted or listing succeeded
  1                 Repository is not trusted
  2                 Error occurred

Examples:
  mt git trusted              # Check current directory
  mt git trusted ~/project    # Check specific directory
  mt git trusted --list       # List all trusted patterns
EOF
    return 0
  fi
  
  # Check if trust file exists
  if [[ ! -f "$trust_file" ]]; then
    _mt_error "Trust patterns file not found: $trust_file"
    return 2
  fi
  
  # Change to the directory
  if ! cd "$dir" 2>/dev/null; then
    _mt_error "Cannot access directory: $dir"
    return 2
  fi
  
  # Check if it's a git repository
  if [[ ! -d .git ]]; then
    echo "NOT_GIT: $dir"
    return 1
  fi
  
  # Get the remote origin URL
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  
  if [[ -z "$remote_url" ]]; then
    echo "NO_REMOTE: $dir"
    return 1
  fi
  
  # Read trusted patterns and check for matches
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # Convert glob pattern to regex for prefix matching
    # Escape special regex characters except *
    local pattern
    pattern=$(echo "$line" | sed 's/[.[\$()+?{|]/\\&/g' | sed 's/\*/.*$/g')
    
    # Check if URL starts with this pattern
    if [[ "$remote_url" =~ ^${pattern} ]]; then
      echo "TRUSTED: $remote_url"
      return 0
    fi
  done < "$trust_file"
  
  echo "UNTRUSTED: $remote_url"
  return 1
}

# Add repository to nearest .repos.txt file
_mt_git_add() {
  local repo=""
  local alias=""
  local auto_yes="${MT_GIT_AUTO_ADD:-}"
  local help=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        help=true
        shift
        ;;
      -y|--yes)
        auto_yes="true"
        shift
        ;;
      *)
        if [[ -z "$repo" ]]; then
          repo="$1"
        elif [[ -z "$alias" ]]; then
          alias="$1"
        fi
        shift
        ;;
    esac
  done
  
  # Show help if requested
  if [[ "$help" == "true" ]]; then
    cat << EOF
Usage: mt git add [REPO] [ALIAS]

Add a repository to the nearest .repos.txt file

Arguments:
  REPO              Repository URL or current directory (default: current)
  ALIAS             Custom alias for the repository

Options:
  -y, --yes         Add without prompting
  -h, --help        Show this help message

Environment:
  MT_GIT_AUTO_ADD   Set to 'true' to always add without prompting

Examples:
  mt git add                        # Add current repository
  mt git add owner/repo             # Add specific repository
  mt git add owner/repo my-alias   # Add with custom alias
  mt git add --yes                 # Add current repo without prompt

EOF
    return 0
  fi
  
  # Get current repo if not specified
  if [[ -z "$repo" ]]; then
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      _mt_error "Not in a git repository"
      return 1
    fi
    repo=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$repo" ]]; then
      _mt_error "No remote origin configured"
      return 1
    fi
  fi
  
  # Normalize the repository URL
  local normalized_repo
  if [[ "$repo" =~ ^(https://|git@) ]]; then
    # Already a full URL
    normalized_repo="$repo"
  else
    # Convert shorthand to full URL
    normalized_repo="$(_mt_repo_url "$repo")"
  fi
  
  # Convert full URL back to repos.txt format (owner/repo or special format)
  local repos_entry
  if [[ "$normalized_repo" =~ git@github\.com_([^:]+):([^/]+)/([^\.]+) ]]; then
    # Special SSH identity format
    local identity="${BASH_REMATCH[1]}"
    local owner="${BASH_REMATCH[2]}"
    local repo_name="${BASH_REMATCH[3]}"
    repos_entry="github.com_${identity}:${owner}/${repo_name}"
  elif [[ "$normalized_repo" =~ (git@|https://)github\.com[:/]([^/]+)/([^\.]+) ]]; then
    # Standard GitHub format - use owner/repo shorthand
    local owner="${BASH_REMATCH[2]}"
    local repo_name="${BASH_REMATCH[3]}"
    repos_entry="${owner}/${repo_name}"
  else
    # Non-GitHub or complex format - use as-is
    repos_entry="$repo"
  fi
  
  # Find repos.txt file
  local repos_file
  if ! repos_file=$(_mt_find_repos_file); then
    # No repos.txt found, offer to create one
    if ! _mt_prompt_create_repos_file; then
      return 1
    fi
    # Try finding again after creation
    if ! repos_file=$(_mt_find_repos_file); then
      _mt_error "Failed to find or create .repos.txt"
      return 1
    fi
  fi
  
  # Add entry to repos.txt
  if _mt_add_to_repos_file "$repos_file" "$repos_entry" "$alias" "$auto_yes"; then
    return 0
  else
    return 1
  fi
}

# Helper to add entry to repos.txt
_mt_add_to_repos_file() {
  local file="$1"
  local repo="$2"
  local alias="${3:-}"
  local auto_yes="${4:-}"
  
  # Check for exact duplicate (repo and alias)
  local entry
  if [[ -n "$alias" ]]; then
    entry="${repo}	${alias}"
  else
    entry="$repo"
  fi
  
  # Check if entry already exists (match beginning of line to handle tabs/spaces)
  if grep -q "^${repo}\\([ 	]\\|$\\)" "$file" 2>/dev/null; then
    _mt_info "Entry already exists in $(basename "$file"): $repo"
    return 0
  fi
  
  # Prompt unless auto-yes
  if [[ "${auto_yes}" != "true" ]]; then
    if [[ -n "$alias" ]]; then
      echo -n "Add '${repo}' as '${alias}' to $(basename "$file")? [y/N] "
    else
      echo -n "Add '${repo}' to $(basename "$file")? [y/N] "
    fi
    read -r response
    if [[ ! "$response" =~ ^[Yy] ]]; then
      _mt_info "Skipped adding entry"
      return 0
    fi
  fi
  
  # Add to file
  echo "$entry" >> "$file"
  if [[ -n "$alias" ]]; then
    _mt_info "Added to $(basename "$file"): ${repo} as ${alias}"
  else
    _mt_info "Added to $(basename "$file"): ${repo}"
  fi
  return 0
}

# Prompt to create repos.txt
_mt_prompt_create_repos_file() {
  local current_dir="$(pwd)"
  local git_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  
  echo "No .repos.txt found in directory tree."
  echo "Where would you like to create it?"
  echo "  1) Current directory ($current_dir)"
  if [[ -n "$git_root" && "$git_root" != "$current_dir" ]]; then
    echo "  2) Git root ($git_root)"
    echo "  3) Cancel"
    local max_choice=3
  else
    echo "  2) Cancel"
    local max_choice=2
  fi
  
  echo -n "Choice [1-${max_choice}]: "
  read -r choice
  
  case "$choice" in
    1)
      touch "${current_dir}/.repos.txt"
      _mt_info "Created .repos.txt in current directory"
      return 0
      ;;
    2)
      if [[ "$max_choice" == "3" && -n "$git_root" ]]; then
        touch "${git_root}/.repos.txt"
        _mt_info "Created .repos.txt at git root"
        return 0
      else
        _mt_info "Cancelled"
        return 1
      fi
      ;;
    *)
      _mt_info "Cancelled"
      return 1
      ;;
  esac
}

_mt_repo_url() {
    local repo="${1:-.}"

    # Return the remote origin URL of a git repository if it's a local directory.
    if [[ -d "$repo" ]]; then
        git -C "$repo" config --get remote.origin.url && return
    fi

    # Extract the optional protocol, host, and user/org from the input if provided
    local git_base_dir="${MT_GIT_BASE_DIR}"
    local protocol="${MT_GIT_PROTOCOL_DEFAULT:-git}"
    local host="${MT_GIT_HOST_DEFAULT:-github.com}"
    local github_user="${MT_GIT_USER_DEFAULT}"
    
    # Handle full URLs first (they take precedence over shorthand)
    
    # Handle git@host:user/repo format (full SSH URL)
    if [[ "$repo" =~ ^git@([^:]+):([^/]+)/([^/:@]+)$ ]]; then
        local ssh_host="${BASH_REMATCH[1]}"
        local user="${BASH_REMATCH[2]}"
        local repo_name="${BASH_REMATCH[3]}"
        
        # Add .git only if not already present
        if [[ "$repo_name" == *.git ]]; then
            echo "git@${ssh_host}:${user}/${repo_name}"
        else
            echo "git@${ssh_host}:${user}/${repo_name}.git"
        fi
        return
    fi
    
    # Handle https://host/user/repo format (full HTTPS URL)
    if [[ "$repo" =~ ^https://([^/]+)/([^/]+)/([^/:@]+)$ ]]; then
        local https_host="${BASH_REMATCH[1]}"
        local user="${BASH_REMATCH[2]}"
        local repo_name="${BASH_REMATCH[3]}"
        
        # Add .git only if not already present
        if [[ "$repo_name" == *.git ]]; then
            echo "https://${https_host}/${user}/${repo_name}"
        else
            echo "https://${https_host}/${user}/${repo_name}.git"
        fi
        return
    fi
    
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
                return 1
            fi
        else
            # Explicit identity provided
            repo="github.com_${identity}:${repo_path}"
        fi
    fi
    
    # Handle host_identity:user/repo format (e.g., github.com_mbailey:mbailey/keycutter)
    if [[ "$repo" =~ ^([^:]+):([^/]+)/([^/:@]+)$ ]]; then
        local host_identity="${BASH_REMATCH[1]}"
        local user="${BASH_REMATCH[2]}"
        local repo_name="${BASH_REMATCH[3]}"
        
        # Host identity format ALWAYS uses SSH (it's for SSH key management)
        # The whole point of host_identity is to specify which SSH key to use
        # Add .git only if not already present
        if [[ "$repo_name" == *.git ]]; then
            echo "git@${host_identity}:${user}/${repo_name}"
        else
            echo "git@${host_identity}:${user}/${repo_name}.git"
        fi
        return
    fi

    # if input is foo/bar, generate appropriate URL based on protocol
    if [[ "$repo" =~ ^([^/:@]+)/([^/:@]+)$ ]]; then
        user="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"
        
        if [[ "$protocol" == "ssh" ]] || [[ "$protocol" == "git" ]]; then
            # Add .git only if not already present
            if [[ "$repo_name" == *.git ]]; then
                echo "git@${host}:${user}/${repo_name}"
            else
                echo "git@${host}:${user}/${repo_name}.git"
            fi
        else
            # Add .git only if not already present
            if [[ "$repo_name" == *.git ]]; then
                echo "${protocol}://${host}/${user}/${repo_name}"
            else
                echo "${protocol}://${host}/${user}/${repo_name}.git"
            fi
        fi
        return
    fi 
    
    # Handle :user/repo format (SSH shorthand)
    if [[ "$repo" =~ ^:([^/]+)/([^/:@]+)$ ]]; then
        user="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"
        
        # Always use SSH for :user/repo format
        if [[ "$repo_name" == *.git ]]; then
            echo "git@${host}:${user}/${repo_name}"
        else
            echo "git@${host}:${user}/${repo_name}.git"
        fi
        return
    fi
    
    # Handle host.com/user/repo format (HTTPS shorthand)
    if [[ "$repo" =~ ^([^/:@]+\.[^/:@]+)/([^/]+)/([^/:@]+)$ ]]; then
        local url_host="${BASH_REMATCH[1]}"
        user="${BASH_REMATCH[2]}"
        repo_name="${BASH_REMATCH[3]}"
        
        # Use HTTPS for host.com/user/repo format
        if [[ "$repo_name" == *.git ]]; then
            echo "https://${url_host}/${user}/${repo_name}"
        else
            echo "https://${url_host}/${user}/${repo_name}.git"
        fi
        return
    fi
    
    echo "$repo"
}

_mt_repo_dir() {
    # Return desired path for a git repo
    local git_repo="${1}"
    local git_base_dir="${2:-${MT_GIT_BASE_DIR:-"${HOME}/Code"}}"
    
    # If input already looks like a URL, use it directly
    local git_repo_url
    if [[ "$git_repo" =~ ^(git@|https://) ]]; then
        git_repo_url="$git_repo"
    else
        git_repo_url="$(_mt_repo_url "${git_repo}")"
    fi

    # Extract the host, username, and repo name from the URL
    if [[ "$git_repo_url" =~ (git@|https://)([^/:]+)[:/]([^/]+)/([^\.]+) ]]; then
        local host="${BASH_REMATCH[2]}"
        local user="${BASH_REMATCH[3]}"
        local repo="${BASH_REMATCH[4]}"
        
        # By default, strip the identity suffix from the host for cleaner paths
        # e.g., github.com_mbailey -> github.com
        if [[ "${MT_GIT_INCLUDE_IDENTITY_IN_PATH:-false}" == "true" ]]; then
            # Keep the full host_identity in the path (e.g., github.com_mbailey)
            # This allows different SSH identities to have separate checkouts
            :  # No change needed, use host as-is
        else
            # Strip the identity suffix for cleaner paths
            # github.com_work -> github.com
            host="${host%_*}"
        fi
    else
        _mt_error "Invalid git URL: $git_repo_url"
        return 1
    fi

    echo "${git_base_dir}/${host}/${user}/${repo}"
}

# Helper function to perform the actual git clone, with ordered output
_mt_git_clone() {
    local git_repo_url="$1"
    local git_repo_path="$2"

    # Debug: Show the actual git clone command
    _mt_debug "git clone '${git_repo_url}' '${git_repo_path}'"

    # Create a temporary file to capture output
    local tmp_output
    tmp_output=$(mktemp)

    # Run git clone and capture the result
    if git clone "${git_repo_url}" "${git_repo_path}" > "${tmp_output}" 2>&1; then
        _mt_info "Repository cloned successfully"
        command cat "${tmp_output}"
        command rm "${tmp_output}"
        return 0
    else
        # The clone failed, so output our error message first, then git's output
        _mt_error "Failed to clone repository"
        command cat "${tmp_output}" >&2
        command rm "${tmp_output}"
        
        # IMPORTANT: Always return the error code
        return 1
    fi
}

# Helper function to create a symlink to the git repository
_mt_create_symlink() {
    local current_dir="$1"
    local target_path="$2"
    local parent_dir="$(dirname "${target_path}")"
    
    # Skip if we're already in the parent directory
    if [[ "$current_dir" == "$parent_dir" ]]; then
        return 0
    fi
    
    local repo_name="$(basename "${target_path}")"
    
    # Check if a symlink already exists
    if [[ -L "$repo_name" ]]; then
        local existing_target
        existing_target="$(readlink -f "$repo_name")"
        
        if [[ "$existing_target" == "$target_path" ]]; then
            _mt_info "Symlink exists and points to the correct location: ${repo_name} -> ${target_path}"
        else
            _mt_warning "Symlink exists but points to a different location: ${repo_name} -> ${existing_target}"
            _mt_warning "Expected target: ${target_path}"
        fi
    # Check if a non-symlink file/directory exists with the same name
    elif [[ -e "$repo_name" ]]; then
        # Check if the existing path and target are the same
        local existing_path target_real
        existing_path="$(realpath "$repo_name" 2>/dev/null || echo "$repo_name")"
        target_real="$(realpath "$target_path" 2>/dev/null || echo "$target_path")"

        if [[ "$existing_path" == "$target_real" ]]; then
            # Source and destination are identical, no symlink needed
            _mt_debug "Skipping symlink creation: $repo_name and $target_path are the same"
        else
            _mt_warning "Cannot create symlink: ${repo_name} already exists and is not a symlink"
        fi
    else
        _mt_info "Creating symlink: ${repo_name} -> ${target_path}"
        _mt_create_relative_symlink "${target_path}" "${repo_name}"
    fi
}

_mt_clone_main() {
    local git_repo_url="$1"
    local git_repo_path="$2"
    
    # Ensure the parent directory exists
    command mkdir -p "$(dirname "${git_repo_path}")" || { 
        _mt_error "Failed to create directory: $(dirname "${git_repo_path}")"
        return 1
    }
    
    # Check if the destination directory already exists and is a git repository
    if [[ -d "${git_repo_path}" && -d "${git_repo_path}/.git" ]]; then
        # Check if it's the same repository the user requested
        local existing_remote_url
        existing_remote_url=$(git -C "${git_repo_path}" config --get remote.origin.url 2>/dev/null)
        
        # Compare normalized URLs (strip trailing .git if present)
        local normalized_existing="${existing_remote_url%.git}"
        local normalized_requested="${git_repo_url%.git}"
        
        if [[ "${normalized_existing}" == "${normalized_requested}" ]]; then
            _mt_info "Repository already exists at ${git_repo_path}"
            
            # Get repository status
            local current_branch
            current_branch=$(git -C "${git_repo_path}" symbolic-ref --short HEAD 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                current_branch="DETACHED HEAD"
            fi
            _mt_info "Current branch: ${current_branch}"
            
            # Check for uncommitted changes
            if ! git -C "${git_repo_path}" diff-index --quiet HEAD --; then
                _mt_info "Status: Repository has uncommitted changes"
            else
                _mt_info "Status: Working tree is clean"
            fi
            
            # Check if local is behind/ahead of remote
            git -C "${git_repo_path}" fetch origin --quiet
            if git -C "${git_repo_path}" rev-parse --abbrev-ref @{upstream} &>/dev/null; then
                local behind_ahead
                behind_ahead=$(git -C "${git_repo_path}" rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
                if [[ $? -eq 0 ]]; then
                    local behind_count ahead_count
                    behind_count=$(echo "$behind_ahead" | cut -f1)
                    ahead_count=$(echo "$behind_ahead" | cut -f2)
                    
                    if [[ "${behind_count}" -gt 0 ]]; then
                        _mt_info "Status: Local branch is behind remote by ${behind_count} commit(s)"
                    fi
                    
                    if [[ "${ahead_count}" -gt 0 ]]; then
                        _mt_info "Status: Local branch is ahead of remote by ${ahead_count} commit(s)"
                    fi
                    
                    if [[ "${behind_count}" -eq 0 && "${ahead_count}" -eq 0 ]]; then
                        _mt_info "Status: Local branch is up to date with remote"
                    fi
                fi
            else
                _mt_info "Status: Branch has no upstream configured"
            fi
            
            # Create symlink in current dir if we're not already in the parent directory
            _mt_create_symlink "$(pwd)" "${git_repo_path}"
            
            return 0
        else
            _mt_error "Directory ${git_repo_path} already exists but contains a different repository"
            _mt_info "Existing remote: ${existing_remote_url}"
            _mt_info "Requested: ${git_repo_url}"
            return 1
        fi
    fi
    
    # Destination doesn't exist or isn't a git repo, proceed with clone
    if _mt_git_clone "${git_repo_url}" "${git_repo_path}"; then
        # Create symlink in current dir if we're not already in the parent directory
        _mt_create_symlink "$(pwd)" "${git_repo_path}"
        return 0
    else
        return 1
    fi
}

# Check if a repository has updates available from remote
# Returns status and optionally outputs commit counts
# Usage: _mt_check_repo_updates <repo_path>
# Returns: 0 for success, non-zero for errors
# Output: STATUS\tBEHIND_COUNT\tAHEAD_COUNT
#   STATUS can be: current, behind, ahead, diverged, no-upstream, no-remote
_mt_check_repo_updates() {
    local repo_path="${1:?Repository path required}"
    
    # Verify it's a git repository
    if [[ ! -d "${repo_path}/.git" ]]; then
        _mt_debug "Not a git repository: ${repo_path}"
        return 1
    fi
    
    # Check if repository has a remote
    if ! git -C "${repo_path}" config --get remote.origin.url &>/dev/null; then
        _mt_debug "No remote origin configured for: ${repo_path}"
        echo -e "no-remote\t0\t0"
        return 0
    fi
    
    # Get current branch
    local current_branch
    current_branch=$(git -C "${repo_path}" symbolic-ref --short HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        _mt_debug "Repository in detached HEAD state: ${repo_path}"
        echo -e "detached\t0\t0"
        return 0
    fi
    
    # Fetch latest changes from remote (quietly, without updating working directory)
    _mt_debug "Fetching updates for: ${repo_path}"
    if ! git -C "${repo_path}" fetch origin --quiet 2>/dev/null; then
        _mt_warning "Failed to fetch from remote for: ${repo_path}"
        # Network issue or permissions - we can't determine status
        return 2
    fi
    
    # Check if branch has upstream configured
    if ! git -C "${repo_path}" rev-parse --abbrev-ref @{upstream} &>/dev/null; then
        _mt_debug "No upstream configured for branch ${current_branch} in: ${repo_path}"
        echo -e "no-upstream\t0\t0"
        return 0
    fi
    
    # Get behind/ahead counts
    local behind_ahead
    behind_ahead=$(git -C "${repo_path}" rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        _mt_warning "Failed to compare with upstream for: ${repo_path}"
        return 3
    fi
    
    # Parse the counts
    local behind_count ahead_count
    behind_count=$(echo "$behind_ahead" | cut -f1)
    ahead_count=$(echo "$behind_ahead" | cut -f2)
    
    # Determine status
    local status
    if [[ "${behind_count}" -eq 0 && "${ahead_count}" -eq 0 ]]; then
        status="current"
    elif [[ "${behind_count}" -gt 0 && "${ahead_count}" -eq 0 ]]; then
        status="behind"
    elif [[ "${behind_count}" -eq 0 && "${ahead_count}" -gt 0 ]]; then
        status="ahead"
    else
        status="diverged"
    fi
    
    _mt_debug "Repository ${repo_path}: ${status} (behind: ${behind_count}, ahead: ${ahead_count})"
    echo -e "${status}\t${behind_count}\t${ahead_count}"
    return 0
}


_mt_clone() {
    # Default settings (can be overridden by environment variables)
    : "${MT_GIT_PROTOCOL_DEFAULT:=git}"
    : "${MT_GIT_HOST_DEFAULT:=github.com}"
    : "${MT_GIT_USER_DEFAULT:=mbailey}"
    : "${MT_GIT_BASE_DIR:=${HOME}/Code}"

    local git_repo=""
    local git_repo_path=""
    local include_identity_in_path=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                git_repo="--help"
                break
                ;;
            --include-identity-in-path)
                include_identity_in_path=true
                shift
                ;;
            *)
                if [[ -z "$git_repo" ]]; then
                    git_repo="$1"
                elif [[ -z "$git_repo_path" ]]; then
                    git_repo_path="$1"
                else
                    _mt_error "Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Show usage if no arguments provided or if help is requested
    if [[ -z $git_repo || "$git_repo" == "--help" ]]; then
        echo "Usage: mt clone [options] <git_repo> [<destination_path>]"
        echo
        echo "Clone a git repository to a canonical location."
        echo "If the repository already exists, display its status instead."
        echo
        echo "Arguments:"
        echo "  <git_repo>         Git repository URL or shorthand (e.g., 'user/repo')"
        echo "  <destination_path> Optional custom destination path"
        echo
        echo "Options:"
        echo "  --include-identity-in-path  Include SSH identity in canonical paths"
        echo "  -h, --help                  Show this help message"
        echo
        echo "Environment variables:"
        echo "  MT_GIT_PROTOCOL_DEFAULT        Default protocol (default: git)"
        echo "  MT_GIT_HOST_DEFAULT            Default host (default: github.com)"
        echo "  MT_GIT_USER_DEFAULT            Default user (default: mbailey)"
        echo "  MT_GIT_BASE_DIR                Base directory for repositories (default: ~/Code)"
        echo "  MT_GIT_INCLUDE_IDENTITY_IN_PATH Include SSH identity in paths (default: false)"
        echo
        echo "Examples:"
        echo "  mt clone https://github.com/mbailey/metool"
        echo "  mt clone mbailey/metool"
        echo "  mt clone user/repo"
        echo "  mt clone --include-identity-in-path github.com_work:company/repo"
        return 1
    fi

    # Set environment variable if CLI option was used
    if [[ "$include_identity_in_path" == "true" ]]; then
        export MT_GIT_INCLUDE_IDENTITY_IN_PATH=true
    fi

    # Resolve repository URL and path
    local git_repo_url
    local git_repo_path
    
    git_repo_url="$(_mt_repo_url "${git_repo}")"
    if [[ -z $git_repo_path ]]; then
        git_repo_path="$(_mt_repo_dir "${git_repo_url}")"
    fi

    # Validate inputs
    if [[ -z $git_repo_url ]] || [[ -z $git_repo_path ]]; then
        _mt_error "Failed to determine repository URL or destination path"
        return 1
    fi
    
    {
        # Print informational messages
        _mt_info "Cloning: ${git_repo_url}"
        _mt_info "To: ${git_repo_path}"
        
        # Call the main function with the resolved parameters
        _mt_clone_main "${git_repo_url}" "${git_repo_path}"
        return $?
    } 2>&1
}