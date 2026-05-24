#!/usr/bin/env bash
# repos.sh - Repository discovery functions

# Discover git repositories via symlinks
_mt_repos_discover() {
  local recursive=false
  local columnise=false
  local search_path="."

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -r|--recursive)
        recursive=true
        shift
        ;;
      -c|--columnise)
        columnise=true
        shift
        ;;
      -h|--help)
        cat << EOF
Usage: mt git repos [-r] [-c] [PATH]

List git repositories and output in repos.txt format.

URLs are read from .git/config verbatim -- the alias form you originally
cloned with (e.g. failmode:mbailey/repo), not the post-insteadOf rewrite
(e.g. ms2:git/repos/repo). The reasoning: this output is for your
.repos.txt, which should reflect what you wrote. If you want git's
effective fetch URL, use 'git remote get-url' directly.

Options:
  -r, --recursive    Recursively scan subdirectories
  -c, --columnise    Force column formatting even when piping to file
  PATH               Directory to scan (default: current directory)

Output format:
  owner/repo [alias]

Where owner/repo is extracted from git remote origin and alias is the symlink path
(only shown when different from repo name).

Examples:
  mt git repos              # List repos in current directory
  mt git repos -r           # List repos recursively
  mt git repos -c > repos.txt  # Create columnised repos.txt file
  mt git repos -r ~/        # List repos recursively from home
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
      
      # Read the remote URL verbatim from .git/config -- the value the user
      # actually wrote, with no url.<base>.insteadOf rewrites applied. This
      # output is destined for a .repos.txt the user maintains, so it should
      # reflect what they typed (alias form, etc.) rather than git's
      # effective fetch URL. Using `git remote get-url` here would silently
      # rewrite e.g. `failmode:mbailey/repo` to `ms2:git/repos/repo` -- not
      # what we want.
      local remote_url
      remote_url=$(cd "$target" && git config --get remote.origin.url 2>/dev/null)
      
      # Skip if no remote
      if [[ -z "$remote_url" ]]; then
        continue
      fi
      
      # Parse owner/repo from the URL
      local owner_repo
      owner_repo=$(_mt_parse_git_url "$remote_url")
      
      # Skip if we couldn't parse -- warn so the user knows we saw the repo
      # but couldn't represent it in .repos.txt shape (see MT-66).
      if [[ -z "$owner_repo" ]]; then
        _mt_warning "Cannot parse remote URL \"$remote_url\" at $path"
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
      
      # Extract just the repo name from owner/repo
      local repo_name="${owner_repo##*/}"
      
      # Output in repos.txt format with tab separation
      # Only include alias if it's different from the repo name
      if [[ "$alias" == "$repo_name" ]]; then
        printf "%s\n" "$owner_repo"
      else
        printf "%s\t%s\n" "$owner_repo" "$alias"
      fi
    done | sort | uniq
  }
  
  # Find both symlinks and regular directories containing .git
  local output
  if [[ "$recursive" == "false" ]]; then
    # Find symlinks and directories with .git subdirectory (non-recursive)
    output=$({ command find "$search_path" -maxdepth 1 -type l -print0 2>/dev/null; \
      command find "$search_path" -maxdepth 2 -type d -name ".git" -print0 2>/dev/null | while IFS= read -r -d '' gitdir; do
        printf "%s\0" "$(dirname "$gitdir")"
      done; } | process_git_repos)
  else
    # Find symlinks and directories with .git subdirectory (recursive)
    output=$({ command find "$search_path" -type l -print0 2>/dev/null; \
      command find "$search_path" -type d -name ".git" -print0 2>/dev/null | while IFS= read -r -d '' gitdir; do
        printf "%s\0" "$(dirname "$gitdir")"
      done; } | process_git_repos)
  fi
  
  # Apply columnise if requested
  if [[ "$columnise" == "true" ]]; then
    if [[ -n "$output" ]]; then
      echo "$output" | columnise --force
    fi
  else
    if [[ -n "$output" ]]; then
      echo "$output"
    fi
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
  elif [[ "$url" =~ ^([^:/@]+):(.+)$ ]]; then
    # ssh_config Host alias form: host:path or host:path.git
    # e.g. failmode:mbailey/skillify, ms2:git/repos/foo.git, ms2:~/git/repos/mfp.git
    # MUST stay last -- [^:/@]+ would shadow `https` if placed before the
    # https?:// patterns. The git@ patterns are safe (literal `@` blocks the
    # alternative class), but order-by-defence is cheaper than order-by-proof.
    # Alias prefix is preserved verbatim so the output round-trips through
    # mt sync / mt clone, which already understand host_identity:user/repo.
    local _alias_host="${BASH_REMATCH[1]}"
    local _alias_path="${BASH_REMATCH[2]%.git}"
    owner_repo="${_alias_host}:${_alias_path}"
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