# Functions for .repos.txt manifest file discovery and parsing

# Parse a repos.txt file and output TSV format: repo target
# Strategy support has been removed - all repos use shared strategy
_mt_git_manifest_parse() {
  local repos_file="${1:?repos file path required}"

  if [[ ! -f "$repos_file" ]]; then
    _mt_error "repos file not found: $repos_file"
    return 1
  fi

  # Process each line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip carriage returns (for Windows line endings)
    line="${line//$'\r'/}"

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

    # MT-72: delegate URL recognition (alias expansion, @version stripping,
    # host_identity prefix detection, .git stripping) to the canonical parser.
    # The previous %%@* greedy strip is the D9 bug class -- it eats `git@` and
    # yields base_name=git for any git@host:owner/repo input. The new parser
    # uses an anchored regex (@[^/:@]+$) that avoids that.
    #
    # The `repo` token is emitted verbatim; downstream callers re-parse it via
    # _mt_url_to_fetch which handles every shape (_alias:, host_identity:,
    # https://..., git@host:..., owner/repo) uniformly.
    local base_name
    local -A _u
    if _mt_url_parse "$repo" _u; then
      base_name="${_u[repo_name]}"
    else
      _mt_error "${_u[error]:-unparseable URL}: '$repo'"
      continue
    fi

    # Parse arguments based on number of tokens
    case ${#tokens[@]} in
      1)
        # Just repo: use default name
        target_name="$base_name"
        ;;
      2|*)
        # Two or more tokens: repo + target_name
        # Skip legacy "shared"/"local" strategy tokens
        if [[ "${tokens[1]}" == "shared" || "${tokens[1]}" == "local" ]]; then
          target_name="$base_name"
        else
          target_name="${tokens[1]}"
        fi
        ;;
    esac

    # Output in TSV format: repo target
    printf "%s\t%s\n" "$repo" "$target_name"

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
_mt_git_manifest_find() {
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

  # Check if MT_PULL_FILE environment variable is set (was MT_SYNC_FILE)
  if [[ -n "${MT_PULL_FILE:-}" ]]; then
    local env_file="$search_dir/$MT_PULL_FILE"
    if [[ -f "$env_file" ]]; then
      echo "$env_file"
      return 0
    else
      return 1
    fi
  fi

  # Legacy: also check MT_SYNC_FILE for backwards compatibility
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

# Parse command line arguments for mt git pull/push
# Arguments:
#   $@ - command line arguments
# Output:
#   Key=value pairs for parsed options
_mt_git_manifest_parse_args() {
  local repos_file=""
  local work_dir=""
  local dry_run=false
  local quick=false
  local rebase=false
  local show_help=false
  # MT-73: parallel job count. Default 1 (off / serial). MT_GIT_JOBS env
  # var seeds the default; an explicit --parallel N flag wins.
  local parallel="${MT_GIT_JOBS:-1}"

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
    echo "QUICK=$quick"
    echo "REBASE=$rebase"
    echo "SHOW_HELP=$show_help"
    echo "PARALLEL=$parallel"
    return 0
  fi

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help=true
        shift
        ;;
      -f|--file)
        repos_file="$2"
        shift 2
        ;;
      -n|--dry-run)
        dry_run=true
        shift
        ;;
      -q|--quick)
        quick=true
        shift
        ;;
      -r|--rebase)
        rebase=true
        shift
        ;;
      -P|--parallel)
        if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
          _mt_error "--parallel requires a positive integer (got: '${2:-}')"
          return 1
        fi
        if (( $2 < 1 )); then
          _mt_error "--parallel must be >= 1 (got: $2)"
          return 1
        fi
        parallel="$2"
        shift 2
        ;;
      -p|--protocol)
        export MT_GIT_PROTOCOL_DEFAULT="$2"
        shift 2
        ;;
      -v|--verbose)
        export MT_VERBOSE=true
        shift
        ;;
      --force)
        export MT_FORCE=true
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
            # Use discovery logic for directories
            if repos_file=$(_mt_git_manifest_find "$work_dir"); then
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
    if repos_file=$(_mt_git_manifest_find); then
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

  # Output parsed values
  echo "REPOS_FILE=$repos_file"
  echo "WORK_DIR=$work_dir"
  echo "DRY_RUN=$dry_run"
  echo "QUICK=$quick"
  echo "REBASE=$rebase"
  echo "SHOW_HELP=$show_help"
  echo "PARALLEL=$parallel"

  return 0
}
