# Common functions for git pull/push operations

# Output summary in TSV format
# Arguments:
#   $1 - summary title (e.g., "Pull Summary:" or "Push Summary:")
#   $@ - Array of results (repo<tab>ref<tab>status<tab>target)
_mt_git_summary() {
  local title="${1:-Summary:}"
  shift

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  echo
  echo "$title"

  # Create TSV output
  {
    printf "REPO\tREF\tSTATUS\tTARGET\n"
    printf -- "----\t---\t------\t------\n"

    for result in "$@"; do
      echo -e "$result"
    done
  } | columnise
}

# Check repository status relative to remote
# Arguments:
#   $1 - repository path
# Output:
#   "current" - up to date with remote
#   "behind" - local is behind remote
#   "ahead" - local is ahead of remote
#   "diverged" - local and remote have diverged
# Returns:
#   0 on success, 1 on error
_mt_git_repo_status() {
  local repo_path="${1:?repository path required}"

  if [[ ! -d "$repo_path/.git" ]]; then
    echo "not-git"
    return 1
  fi

  # Get current branch
  local current_branch
  current_branch=$(git -C "$repo_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

  if [[ -z "$current_branch" || "$current_branch" == "HEAD" ]]; then
    # Detached HEAD state
    echo "detached"
    return 0
  fi

  # Get local and remote refs
  local local_ref remote_ref
  local_ref=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null)
  remote_ref=$(git -C "$repo_path" rev-parse "origin/$current_branch" 2>/dev/null)

  if [[ -z "$remote_ref" ]]; then
    # No remote tracking branch
    echo "no-remote"
    return 0
  fi

  if [[ "$local_ref" == "$remote_ref" ]]; then
    echo "current"
    return 0
  fi

  # Check if we're ahead, behind, or diverged
  local base
  base=$(git -C "$repo_path" merge-base "$local_ref" "$remote_ref" 2>/dev/null)

  if [[ "$base" == "$remote_ref" ]]; then
    echo "ahead"
  elif [[ "$base" == "$local_ref" ]]; then
    echo "behind"
  else
    echo "diverged"
  fi

  return 0
}

# Check if repository has uncommitted changes
# Arguments:
#   $1 - repository path
# Returns:
#   0 if clean, 1 if dirty
_mt_git_is_clean() {
  local repo_path="${1:?repository path required}"

  if git -C "$repo_path" diff-index --quiet HEAD -- 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Get current branch or ref
# Arguments:
#   $1 - repository path
# Output:
#   Branch name, tag name, or short commit hash
_mt_git_current_ref() {
  local repo_path="${1:?repository path required}"

  # Try to get symbolic ref (branch name)
  local ref
  ref=$(git -C "$repo_path" symbolic-ref --short HEAD 2>/dev/null)
  if [[ -n "$ref" ]]; then
    echo "$ref"
    return 0
  fi

  # Not on a branch, might be a tag
  ref=$(git -C "$repo_path" describe --exact-match --tags HEAD 2>/dev/null)
  if [[ -n "$ref" ]]; then
    echo "$ref"
    return 0
  fi

  # Just show commit hash
  git -C "$repo_path" rev-parse --short HEAD 2>/dev/null
}

# Resolve repository spec to canonical path
# Arguments:
#   $1 - repository spec (e.g., "user/repo" or "user/repo@version")
# Output:
#   repo_url repo_path version (tab-separated)
_mt_git_resolve_repo() {
  local repo_spec="${1:?repository spec required}"

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
  git_repo_path="$(_mt_repo_dir "$git_repo_url")"

  printf "%s\t%s\t%s\n" "$git_repo_url" "$git_repo_path" "$version"
}
