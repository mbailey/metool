_mt_cd() {
  if (($# != 1)); then
    echo "Usage: mt cd <file|function|executable>" >&2
    return 1
  fi

  funcinfo=($(declare -F "${1}"))
  if ((${#funcinfo[@]} > 0)); then
    source_file=${funcinfo[2]}
    if [[ -f $source_file ]]; then
      cd "$(dirname "$source_file")"
      return
    fi
  fi

  exec_path=$(which "${1}" 2>/dev/null)
  if [[ -n $exec_path ]]; then
    cd "$(dirname "$exec_path")"
    return
  fi

  echo "Error: '${1}' not found" >&2
  return 1
}

_mt_path_to() {
  if (($# != 1)); then
    echo "Usage: mt path-to <function|executable>" >&2
    return 1
  fi

  shopt -s extdebug
  funcinfo=($(declare -F "${1}"))
  if ((${#funcinfo[@]} > 0)); then
    echo "${funcinfo[2]}"
  else
    exec_path=$(which "${1}" 2>/dev/null)
    if [[ -n $exec_path ]]; then
      echo "$exec_path"
    else
      echo "Error: '${1}' not found" >&2
      return 1
    fi
  fi
}

_mt_path_append() {
  if [[ $# -eq 0 ]]; then
    _mt_error "No directories provided to _mt_path_append()"
    return 1
  fi

  local new_path="$PATH"
  local dirs_to_append=""

  # Process each argument
  for dir in "$@"; do
    if [[ -z $dir ]]; then
      _mt_debug "Empty directory argument skipped"
      continue
    fi

    if [[ ! -d $dir ]]; then
      _mt_debug "Directory does not exist: $dir"
      continue
    fi

    # Use the original path without resolving symlinks

    # Remove this dir from the path if it already exists
    new_path=":${new_path}:"
    new_path="${new_path//:$dir:/:}"
    new_path="${new_path#:}"
    new_path="${new_path%:}"

    # Add to the list of dirs to append
    if [[ -z $dirs_to_append ]]; then
      dirs_to_append="$dir"
    else
      dirs_to_append="$dirs_to_append:$dir"
    fi

    _mt_debug "Prepared for appending to PATH: ${dir}"
  done

  # If we have directories to append, add them to the PATH
  if [[ -n $dirs_to_append ]]; then
    export PATH="$new_path:$dirs_to_append"
    _mt_debug "PATH updated with appended directories"
  fi
}
mt_path_append() {
  _mt_path_append "$@"
}

_mt_path_prepend() {
  if [[ $# -eq 0 ]]; then
    _mt_error "No directories provided to _mt_path_prepend()"
    return 1
  fi

  local new_path="$PATH"
  local dirs_to_prepend=""

  # Process each argument
  for dir in "$@"; do
    if [[ -z $dir ]]; then
      _mt_debug "Empty directory argument skipped"
      continue
    fi

    if [[ ! -d $dir ]]; then
      _mt_debug "Directory does not exist: $dir"
      continue
    fi

    # Use the original path without resolving symlinks

    # Remove this dir from the path if it already exists
    new_path=":${new_path}:"
    new_path="${new_path//:$dir:/:}"
    new_path="${new_path#:}"
    new_path="${new_path%:}"

    # Add to the list of dirs to prepend
    if [[ -z $dirs_to_prepend ]]; then
      dirs_to_prepend="$dir"
    else
      dirs_to_prepend="$dirs_to_prepend:$dir"
    fi

    _mt_debug "Prepared for prepending to PATH: ${dir}"
  done

  # If we have directories to prepend, add them to the PATH
  if [[ -n $dirs_to_prepend ]]; then
    export PATH="$dirs_to_prepend:$new_path"
    _mt_debug "PATH updated with prepended directories"
  fi
}
mt_path_prepend() {
  _mt_path_prepend "$@"
}

_mt_path_rm() {
  if [[ $# -eq 0 ]]; then
    _mt_error "No directories provided to _mt_path_rm()"
    return 1
  fi

  local new_path="$PATH"

  # Process each argument
  for dir in "$@"; do
    if [[ -z $dir ]]; then
      _mt_debug "Empty directory argument skipped"
      continue
    fi

    if [[ ! -d $dir ]]; then
      _mt_debug "Directory does not exist: $dir"
      continue
    fi

    # Use the original path without resolving symlinks

    # Remove this dir from the path if it already exists
    if [[ ":$new_path:" == *":$dir:"* ]]; then
      new_path=":${new_path}:"
      new_path="${new_path//:$dir:/:}"
      new_path="${new_path#:}"
      new_path="${new_path%:}"
      _mt_debug "Removed from PATH: $dir"
    else
      _mt_debug "Not in PATH: $dir"
    fi
  done

  # Update PATH with all removals
  export PATH="$new_path"
}
alias mt_path_rm=_mt_path_rm
