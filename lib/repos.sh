#!/usr/bin/env bash
# repos.sh - Repository discovery functions

# Discover git repositories via symlinks
_mt_repos_discover() {
  local recursive=false
  local search_path="."
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--recursive)
        recursive=true
        shift
        ;;
      -h|--help)
        cat << EOF
Usage: mt repos discover [-r] [PATH]

Discover git repositories accessible via symlinks and output in repos.txt format

Options:
  -r, --recursive    Recursively scan subdirectories
  PATH              Directory to scan (default: current directory)

Output format:
  owner/repo alias

Where owner/repo is extracted from git remote origin and alias is the symlink path.

Examples:
  mt repos discover              # Discover in current directory
  mt repos discover -r           # Discover recursively
  mt repos discover -r ~/        # Discover recursively from home
  mt repos discover > repos.txt  # Create repos.txt file
EOF
        return 0
        ;;
      *)
        # Assume it's the path
        search_path="$1"
        shift
        ;;
    esac
  done
  
  # Validate search path
  if [[ ! -d "$search_path" ]]; then
    _mt_error "Directory not found: $search_path"
    return 1
  fi
  
  # Process git repositories (either symlinks or regular directories)
  process_git_repos() {
    while IFS= read -r -d '' path; do
      # Skip if path is the search_path itself
      if [[ "$path" == "$search_path" ]]; then
        continue
      fi
      
      # If it's a symlink, resolve it
      local target="$path"
      if [[ -L "$path" ]]; then
        target=$(readlink -f "$path" 2>/dev/null)
        # Check if target exists and is a directory
        if [[ ! -d "$target" ]]; then
          continue
        fi
      fi
      
      # Check if it's a git repository
      if [[ ! -d "$target/.git" ]]; then
        continue
      fi
      
      # Get the remote origin URL
      local remote_url
      remote_url=$(cd "$target" && git remote get-url origin 2>/dev/null)
      
      # Skip if no remote
      if [[ -z "$remote_url" ]]; then
        continue
      fi
      
      # Parse owner/repo from the URL
      local owner_repo
      owner_repo=$(_mt_parse_git_url "$remote_url")
      
      # Skip if we couldn't parse
      if [[ -z "$owner_repo" ]]; then
        continue
      fi
      
      # Get relative path for the alias
      local alias
      if [[ "$search_path" == "." ]]; then
        # For current directory, use basename
        alias=$(basename "$path")
      else
        # For other paths, make it relative if possible
        alias="${path#$search_path/}"
        if [[ "$alias" == "$path" ]]; then
          # Couldn't make relative, use full path
          alias="$path"
        fi
      fi
      
      # Output in repos.txt format
      echo "$owner_repo $alias"
    done | sort | uniq
  }
  
  # Find both symlinks and regular directories containing .git
  if [[ "$recursive" == "false" ]]; then
    # Find symlinks and directories with .git subdirectory (non-recursive)
    { command find "$search_path" -maxdepth 1 -type l -print0 2>/dev/null; \
      command find "$search_path" -maxdepth 2 -type d -name ".git" -print0 2>/dev/null | while IFS= read -r -d '' gitdir; do
        printf "%s\0" "$(dirname "$gitdir")"
      done; } | process_git_repos
  else
    # Find symlinks and directories with .git subdirectory (recursive)
    { command find "$search_path" -type l -print0 2>/dev/null; \
      command find "$search_path" -type d -name ".git" -print0 2>/dev/null | while IFS= read -r -d '' gitdir; do
        printf "%s\0" "$(dirname "$gitdir")"
      done; } | process_git_repos
  fi
}

# Parse git URL to extract owner/repo
_mt_parse_git_url() {
  local url="$1"
  local owner_repo=""
  
  # Handle different git URL formats
  if [[ "$url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
    # SSH format: git@github.com:owner/repo.git
    # or keycutter: git@github.com_alias:owner/repo.git
    owner_repo="${BASH_REMATCH[2]}"
  elif [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
    # SSH format without .git: git@github.com:owner/repo
    owner_repo="${BASH_REMATCH[2]}"
  elif [[ "$url" =~ ^https?://[^/]+/(.+)\.git$ ]]; then
    # HTTPS format: https://github.com/owner/repo.git
    owner_repo="${BASH_REMATCH[1]}"
  elif [[ "$url" =~ ^https?://[^/]+/(.+)$ ]]; then
    # HTTPS format without .git: https://github.com/owner/repo
    owner_repo="${BASH_REMATCH[1]}"
  fi
  
  echo "$owner_repo"
}

# Main repos command dispatcher
_mt_repos() {
  local subcommand="${1:-discover}"
  shift || true
  
  case "$subcommand" in
    discover)
      _mt_repos_discover "$@"
      ;;
    -h|--help)
      cat << EOF
Usage: mt repos <subcommand> [options]

Repository management commands

Subcommands:
  discover    Discover git repositories via symlinks

Run 'mt repos <subcommand> --help' for subcommand-specific help.
EOF
      ;;
    *)
      _mt_error "Unknown repos subcommand: $subcommand"
      echo "Run 'mt repos --help' for usage information."
      return 1
      ;;
  esac
}