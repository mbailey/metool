_mt_edit() {
  if [[ $# != 1 ]]; then
    echo "Usage: mt edit <function, executable or file>" >&2
    return 1
  fi

  editor="${EDITOR:-vim}"

  # Check if it's a file first (including paths with slashes)
  if is_file "${1}"; then
    ${editor} "${1}"
    return $?
  fi

  # Check if it's a function
  if is_function "${1}"; then
    _mt_edit_function "${1}"
    return $?
  fi

  # Check if it's an executable
  if is_executable "${1}"; then
    _mt_edit_executable "${1}"
    return $?
  fi

  _mt_error "Target ${1} not found as function, executable, or file"
  return 1
}

_mt_edit_function() {
  if (($# != 1)); then
    echo "Usage: mt edit-function <function-name>" >&2
    return 1
  fi

  if ! is_function "${1}"; then
    _mt_error "Function '${1}' not found"
    return 1
  fi

  shopt -s extdebug

  funcinfo=($(declare -F "${1}"))
  editor="${EDITOR:-vim}"
  if [[ ${funcinfo[1]} =~ ^[0-9]+$ ]]; then
    if [[ $editor == "code" ]]; then
      code --goto ${funcinfo[2]}:${funcinfo[1]}
    else
      ${editor} +${funcinfo[1]} ${funcinfo[2]}
    fi
  else
    echo ${funcinfo[2]}
    echo "Error: Unable to determine line number for function '${1}'" >&2
    return 1
  fi
}

_mt_edit_executable() {
  if (($# != 1)); then
    echo "Usage: mt edit-executable <executable-name>" >&2
    return 1
  fi

  if ! is_executable "${1}"; then
    _mt_error "Executable '${1}' not found"
    return 1
  fi

  exec_path=$(which "${1}")
  editor="${EDITOR:-vim}"
  ${editor} "${exec_path}"
}
