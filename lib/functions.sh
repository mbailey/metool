# Set default log level if not specified
: "${MT_LOG_LEVEL:=INFO}"

_mt_log() {
  local level=$1
  shift
  local message="$*"

  # Convert level to number for comparison
  case "${level^^}" in
  ERROR) level_num=0 ;;
  WARNING) level_num=1 ;;
  INFO) level_num=2 ;;
  DEBUG) level_num=3 ;;
  *) level_num=2 ;; # Default to INFO
  esac

  # Convert MT_LOG_LEVEL to number
  case "${MT_LOG_LEVEL^^}" in
  ERROR) log_level_num=0 ;;
  WARNING) log_level_num=1 ;;
  INFO) log_level_num=2 ;;
  DEBUG) log_level_num=3 ;;
  *) log_level_num=2 ;; # Default to INFO
  esac

  # Only log if level is less than or equal to MT_LOG_LEVEL
  if ((level_num <= log_level_num)); then
    local color prefix

    # Set color and prefix based on level
    case "${level^^}" in
    ERROR)
      color=$MT_COLOR_ERROR
      prefix="🚫"
      ;;
    WARNING)
      color=$MT_COLOR_WARNING
      prefix="⚠️ "
      ;;
    INFO)
      color=$MT_COLOR_INFO
      prefix="ℹ️ "
      ;;
    DEBUG)
      color=$MT_COLOR_DEBUG
      prefix="🔍"
      ;;
    *)
      color=$MT_COLOR_RESET
      prefix=""
      ;;
    esac

    # Format message with color if terminal supports it
    if [[ -n ${NO_COLOR:-} ]] || [[ ! -t 1 ]]; then
      formatted_msg="${prefix} ${level}: ${message}"
    else
      formatted_msg="${color}${prefix} ${level}: ${message}${MT_COLOR_RESET}"
    fi

    # Output to appropriate stream
    if [[ "${level^^}" == "ERROR" || "${level^^}" == "WARNING" ]]; then
      printf "%b\n" "$formatted_msg" >&2
    else
      printf "%b\n" "$formatted_msg"
    fi
  fi
}

_mt_debug() {
  _mt_log DEBUG "$@"
}
alias mt_debug=_mt_debug

_mt_error() {
  _mt_log ERROR "$@"
}

_mt_warning() {
  _mt_log WARNING "$@"
}

_mt_info() {
  _mt_log INFO "$@"
}

_mt_source() {
  local file="${1:?}"
  shift # remove the first argument
  if [[ -f $file ]]; then
    source "$file"
    _mt_log DEBUG "Sourced ${file}"
  else
    _mt_log DEBUG "Not found: ${file}"
  fi
}

_mt_update() {
  _mt_update_git
  # check_requirements
}

_mt_update_git() {

  _mt_log INFO "Updating mt from git..."

  # Check if we're in a git repository
  if ! git -C "${MT_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _mt_log "Error: ${MT_ROOT} is not a git repository."
    return 1
  fi

  # Get the current branch name
  local current_branch=$(git -C "${MT_ROOT}" symbolic-ref --short HEAD)
  if [ -z "$current_branch" ]; then
    _mt_log "Error: Unable to determine current branch."
    return 1
  fi

  # Check if we're on the master branch
  if [[ "$current_branch" != "master" ]]; then
    _mt_log "Not on master branch. Current branch is $current_branch. Skipping update."
    return 0
  fi

  # Fetch the latest changes
  if ! git -C "${MT_ROOT}" fetch origin; then
    _mt_log "Error: Failed to fetch updates from remote repository."
    return 1
  fi

  # Check if there are any changes to pull
  local behind_by=$(git -C "${MT_ROOT}" rev-list HEAD..origin/"$current_branch" --count 2>/dev/null)
  if [ $? -ne 0 ]; then
    _mt_log "Error: Unable to determine if there are updates available."
    return 1
  fi

  if [ -z "$behind_by" ] || [ "$behind_by" -eq 0 ]; then
    _mt_log "mt is already up to date."
    return 0
  fi

  # Pull the latest changes
  if ! git -C "${MT_ROOT}" pull origin "$current_branch"; then
    _mt_log "Error: Failed to pull updates from remote repository."
    return 1
  fi

  _mt_log "mt git update complete."
}


# Get all metool modules (with caching)
_mt_get_modules() {
  _mt_log DEBUG "_mt_get_modules: Starting module discovery"
  
  # Define cache location
  local cache_dir="${MT_PKG_DIR}/.cache"
  local cache_file="${cache_dir}/modules.tsv"
  local timestamp_file="${cache_dir}/last_update"
  mkdir -p "${cache_dir}"
  
  # Check if we need to regenerate the cache
  if _mt_cache_needs_update "${cache_file}" "${timestamp_file}"; then
    _mt_log DEBUG "_mt_get_modules: Regenerating module cache"
    
    local modules=()
    local module_paths=()
    
    # Process bin directory symlinks
    if [[ -d "${MT_PKG_DIR}/bin" ]]; then
      _mt_log DEBUG "_mt_get_modules: Searching for modules in ${MT_PKG_DIR}/bin"
      while IFS= read -r -d '' symlink; do
        if [[ -L "$symlink" ]]; then
          local target=$(readlink -f "$symlink")
          # Extract path up to the bin directory
          local pkg_path=${target%/bin/*}
          
          # Skip if we couldn't extract a proper path
          if [[ -z "$pkg_path" || "$pkg_path" == "$target" ]]; then
            _mt_log DEBUG "_mt_get_modules: Skipping invalid path: $target"
            continue
          fi
          
          # Get module name (parent directory of package)
          local module_dir=$(dirname "$pkg_path")
          local module_name=$(basename "$module_dir")
          
          # Skip if module name or path is just a dot
          if [[ "$module_name" == "." || "$module_dir" == "." ]]; then
            _mt_log DEBUG "_mt_get_modules: Skipping invalid module: $module_name at $module_dir"
            continue
          fi
          
          # Special case for metool
          if [[ "$(basename "$pkg_path")" == "metool" ]]; then
            module_name="metool"
            module_dir="${MT_ROOT}"
          fi
          
          # Add to modules if not already there
          if [[ ! " ${modules[*]} " =~ " ${module_name} " ]]; then
            modules+=("$module_name")
            module_paths+=("$module_dir")
          fi
        fi
      done < <(find "${MT_PKG_DIR}/bin" -type l -print0)
    fi
    
    # Process shell directory symlinks
    if [[ -d "${MT_PKG_DIR}/shell" ]]; then
      _mt_log DEBUG "_mt_get_modules: Searching for modules in ${MT_PKG_DIR}/shell"
      while IFS= read -r -d '' symlink; do
        if [[ -L "$symlink" ]]; then
          local target=$(readlink -f "$symlink")
          # Extract path up to the shell directory
          local pkg_path=${target%/shell/*}
          
          # Skip if we couldn't extract a proper path
          if [[ -z "$pkg_path" || "$pkg_path" == "$target" ]]; then
            _mt_log DEBUG "_mt_get_modules: Skipping invalid path: $target"
            continue
          fi
          
          # Get module name (parent directory of package)
          local module_dir=$(dirname "$pkg_path")
          local module_name=$(basename "$module_dir")
          
          # Skip if module name or path is just a dot
          if [[ "$module_name" == "." || "$module_dir" == "." ]]; then
            _mt_log DEBUG "_mt_get_modules: Skipping invalid module: $module_name at $module_dir"
            continue
          fi
          
          # Special case for metool
          if [[ "$(basename "$pkg_path")" == "metool" ]]; then
            module_name="metool"
            module_dir="${MT_ROOT}"
          fi
          
          # Add to modules if not already there
          if [[ ! " ${modules[*]} " =~ " ${module_name} " ]]; then
            modules+=("$module_name")
            module_paths+=("$module_dir")
          fi
        fi
      done < <(find "${MT_PKG_DIR}/shell" -type l -print0 2>/dev/null)
    fi
    
    # Always include metool itself as a module if not already found
    if [[ ! " ${modules[*]} " =~ " metool " ]]; then
      modules+=("metool")
      module_paths+=("${MT_ROOT}")
    fi
    
    # Output the modules to cache file
    > "${cache_file}" # Clear the file
    for i in "${!modules[@]}"; do
      echo -e "${modules[$i]}\t${module_paths[$i]}" >> "${cache_file}"
    done
    
    # Sort the cache file
    sort "${cache_file}" -o "${cache_file}"
    
    # Update the timestamp file
    touch "${timestamp_file}"
  fi
  
  # Output the modules from cache
  cat "${cache_file}"
}

# Get all metool packages (with caching)
_mt_get_packages() {
  _mt_log DEBUG "_mt_get_packages: Starting package discovery"
  
  # Define cache location
  local cache_dir="${MT_PKG_DIR}/.cache"
  local cache_file="${cache_dir}/packages.tsv"
  local timestamp_file="${cache_dir}/last_update"
  mkdir -p "${cache_dir}"
  
  # Check if we need to regenerate the cache
  if _mt_cache_needs_update "${cache_file}" "${timestamp_file}"; then
    _mt_log DEBUG "_mt_get_packages: Regenerating package cache"
    
    {
      # Process bin and shell directory symlinks
      for dir in "bin" "shell"; do
        if [[ -d "${MT_PKG_DIR}/${dir}" ]]; then
          _mt_log DEBUG "_mt_get_packages: Searching for packages in ${MT_PKG_DIR}/${dir}"
          find "${MT_PKG_DIR}/${dir}" -type l -print0 2>/dev/null | 
            xargs -0 readlink -f | 
            grep "/${dir}/" | 
            sed "s|/${dir}/.*$||" | 
            while read pkg_path; do
              pkg_name=$(basename "$pkg_path")
              module_dir=$(dirname "$pkg_path")
              module_name=$(basename "$module_dir")
              
              # Special case for metool
              if [[ "$pkg_name" == "metool" ]]; then
                module_name="metool"
              fi
              
              # Skip if module name or path is just a dot
              if [[ "$module_name" == "." || "$module_dir" == "." ]]; then
                _mt_log DEBUG "_mt_get_packages: Skipping invalid module: $module_name at $module_dir"
                continue
              fi
              
              echo -e "${pkg_name}\t${module_name}\t${pkg_path}"
            done
        fi
      done
      
      # Add metool itself
      echo -e "metool\tmetool\t${MT_ROOT}"
      
    } | sort -u -k2,2 -k1,1 > "${cache_file}"
    
    # Update the timestamp file
    touch "${timestamp_file}"
  fi
  
  # Output the packages from cache
  cat "${cache_file}"
}

# Function to check and offer to update .bashrc
_mt_update_bashrc() {
  local bashrc="${HOME}/.bashrc"
  local mt_source_path="${HOME}/.metool/shell/metool/mt"
  local bashrc_line="# metool\n[[ -f \${mt_source:=\"\${HOME}/.metool/shell/metool/mt\"} ]] && source \"\$mt_source\""

  # Check if .bashrc exists
  if [[ ! -f "$bashrc" ]]; then
    _mt_warning "No .bashrc file found at $bashrc"
    return 1
  fi

  # Check if metool is already in .bashrc
  if grep -q "metool/shell/metool/mt" "$bashrc"; then
    # Don't show the "already configured" message - just return silently
    return 0
  fi

  # Show the user what will be added
  echo -e "\nThe following line will be added to your ${bashrc}:\n"
  echo -e "${bashrc_line}"
  echo

  # Ask user if they want to add metool to .bashrc
  # Source prompt functions if needed
  if ! type -t _mt_confirm >/dev/null; then
    source "$(dirname "${BASH_SOURCE[0]}")/prompt.sh"
  fi
  
  _mt_confirm "Would you like to add metool to your .bashrc for automatic loading?"
  if [[ $? -eq 0 ]]; then
    echo -e "\n${bashrc_line}" >>"$bashrc"
    _mt_info "Added metool to $bashrc"
    _mt_info "Restart your shell or run 'source $bashrc' to activate"
    return 0
  else
    _mt_info "To manually enable metool, add this line to your .bashrc:"
    _mt_info "${bashrc_line}"
    return 0
  fi
}

function-info() {
  local extdebug_state=$(shopt -p extdebug) # Save the current state of extdebug
  shopt -s extdebug                         # Enable extended debugging information

  for function in "${@:-function-info}"; do
    declare -F "${function}"
  done

  eval "$extdebug_state" # Restore the original state of extdebug
}

complete -F mt_complete_functions function-info

function-reload() {
  if (($# != 1)); then
    echo "Usage: function-reload <function-name>"
    return 1
  fi

  shopt -s extdebug

  local funcinfo=($(declare -F "${1}"))
  if ((${#funcinfo[@]} == 0)); then
    echo "Error: Function '${1}' not found."
    return 1
  fi

  source "${funcinfo[2]}"
}

complete -F mt_complete_functions function-reload

# Handy function to columnise output
#
# Formats tabular data with aligned columns when output is a terminal,
# but preserves TSV format when piping to another command
columnise() {
  # Check if no arguments are provided
  if [ $# -eq 0 ]; then
    if ! [[ -t 1 ]]; then
      cat
    else
      column -t -s $'\t'
    fi
  else
    # Loop through all arguments
    for file in "$@"; do
      if [ -e "$file" ]; then
        # Process the file if it exists
        column -t -s $'\t' < "$file"
      else
        # Print an error message if the file doesn't exist
        echo "Error: File '$file' does not exist" >&2
      fi
    done
  fi
}

# Helper functions to check what we're editing
is_function() {
  local funcinfo=($(declare -F "${1}"))
  ((${#funcinfo[@]} > 0))
}

is_executable() {
  which "${1}" >/dev/null 2>&1
}

is_file() {
  [[ -f "${1}" ]]
}

# Function to check if cache needs regeneration
_mt_cache_needs_update() {
  local cache_file="$1"
  local timestamp_file="$2"
  
  # If cache doesn't exist, we need to generate it
  if [[ ! -f "${cache_file}" ]]; then
    _mt_log DEBUG "Cache file doesn't exist, will generate"
    return 0
  elif [[ ! -f "${timestamp_file}" ]]; then
    # If timestamp file doesn't exist, regenerate cache and create it
    _mt_log DEBUG "Timestamp file doesn't exist, will generate cache"
    return 0
  fi
  
  # Check if the timestamp file is older than the cache file
  # This would indicate the cache was manually edited or corrupted
  if [[ "${timestamp_file}" -ot "${cache_file}" ]]; then
    _mt_log DEBUG "Cache file is newer than timestamp, will regenerate"
    return 0
  fi
  
  # Check if any files in bin or shell are newer than the timestamp file
  for dir in "bin" "shell"; do
    if [[ -d "${MT_PKG_DIR}/${dir}" ]]; then
      # Find the newest file in the directory
      local newest_file=$(find "${MT_PKG_DIR}/${dir}" -type l -newer "${timestamp_file}" -print -quit)
      if [[ -n "${newest_file}" ]]; then
        _mt_log DEBUG "Found newer files in ${dir}, will regenerate cache"
        return 0
      fi
    fi
  done
  
  _mt_log DEBUG "Using cached data"
  return 1
}

# Function to invalidate the cache
_mt_invalidate_cache() {
  _mt_log DEBUG "Invalidating package and module cache"
  rm -f "${MT_PKG_DIR}/.cache/packages.tsv"
  rm -f "${MT_PKG_DIR}/.cache/modules.tsv"
  # Update the timestamp file to mark when we last invalidated the cache
  mkdir -p "${MT_PKG_DIR}/.cache"
  touch "${MT_PKG_DIR}/.cache/last_update"
}

# Initialize ln command with relative symlink support
_mt_init_ln_command() {
  # Cache the result to avoid repeated checks
  if [[ -n "${_MT_LN_COMMAND:-}" ]]; then
    return 0
  fi
  
  # Check if standard ln supports -r (quickly, without delays)
  if ln -r -s /dev/null /tmp/mt_test_ln_$$ 2>/dev/null; then
    rm -f /tmp/mt_test_ln_$$
    export _MT_LN_COMMAND="ln"
    return 0
  fi
  
  # On macOS, check for GNU ln (gln)
  if command -v gln >/dev/null 2>&1 && gln -r -s /dev/null /tmp/mt_test_gln_$$ 2>/dev/null; then
    rm -f /tmp/mt_test_gln_$$
    export _MT_LN_COMMAND="gln"
    return 0
  fi
  
  # Neither works - prompt for installation
  _mt_error "Relative symlinks require GNU ln with -r support"
  _mt_info "On macOS, you can install GNU coreutils with Homebrew:"
  echo
  echo "  brew install coreutils"
  echo
  echo -n "Would you like to install it now? (Y)es/(N)o [N]: "
  read -r response
  
  if [[ "${response,,}" == "y" || "${response,,}" == "yes" ]]; then
    _mt_info "Running: brew install coreutils"
    if brew install coreutils; then
      # Check again after installation
      if command -v gln >/dev/null 2>&1 && gln -r -s /dev/null /tmp/mt_test_gln_$$ 2>/dev/null; then
        rm -f /tmp/mt_test_gln_$$
        export _MT_LN_COMMAND="gln"
        _mt_info "GNU ln installed successfully"
        return 0
      fi
    fi
  fi
  
  return 1
}

# Create a relative symlink using the appropriate ln command
_mt_create_relative_symlink() {
  local target="${1:?target path required}"
  local link_name="${2:?link name required}"
  
  # Initialize ln command if not already done
  if ! _mt_init_ln_command; then
    return 1
  fi
  
  # Create relative symlink
  "${_MT_LN_COMMAND}" -r -s "$target" "$link_name"
}
