_mt_edit() {
  if [[ $# != 1 ]]; then
    echo "Usage: mt edit <function, executable or file>" >&2
    echo "       Use 'MODULE/PACKAGE' to create a new package in an existing module" >&2
    return 1
  fi

  editor="${EDITOR:-vim}"

  # Check if it's a module/package path (contains a slash)
  if [[ "$1" == */* ]]; then
    local module_name="${1%%/*}"
    local package_name="${1#*/}"

    # Check if the module exists
    local module_path=""
    while IFS=$'\t' read -r mod_name mod_path; do
      if [[ "$mod_name" == "$module_name" ]]; then
        module_path="$mod_path"
        break
      fi
    done < <(_mt_get_modules)

    if [[ -z "$module_path" ]]; then
      _mt_error "Module '$module_name' not found"
      return 1
    fi

    # Construct the package path
    local package_path="${module_path}/${package_name}"

    # Check if the package directory already exists
    if [[ -d "$package_path" ]]; then
      # Package exists, just edit its README
      local readme_path="${package_path}/README.md"
      if [[ ! -f "$readme_path" ]]; then
        _mt_info "Creating README.md for package '$package_name'"
        echo "# ${package_name}" >"${readme_path}"
      fi
      _mt_info "Editing package README: $readme_path"
      ${editor} "$readme_path"
      return 0
    else
      # Package doesn't exist, ask for confirmation to create it
      # Source prompt functions if needed
      if ! type -t _mt_confirm >/dev/null; then
        source "$(dirname "${BASH_SOURCE[0]}")/prompt.sh"
      fi

      _mt_confirm "Package '$package_name' doesn't exist in module '$module_name'.\nWould you like to create it at: $package_path?"
      if [[ $? -eq 0 ]]; then
        _mt_info "Creating package directory: $package_path"
        command mkdir -p "$package_path"
        local readme_path="${package_path}/README.md"
        _mt_info "Creating README.md for package '$package_name'"
        echo "# ${package_name}" >"${readme_path}"
        _mt_info "Editing package README: $readme_path"
        ${editor} "$readme_path"
        return 0
      else
        _mt_info "Package creation cancelled"
        return 1
      fi
    fi
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

  # Check if it's a file
  if is_file "${1}"; then
    ${editor} "${1}"
    return $?
  fi

  _mt_error "Target ${1} not found as package, function, executable, or file"
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
