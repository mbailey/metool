# Functions for git operations

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
        _mt_warning "Cannot create symlink: ${repo_name} already exists and is not a symlink"
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