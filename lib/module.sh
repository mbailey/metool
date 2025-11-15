#!/usr/bin/env bash
# module.sh - Module management commands (MT-11)

# List modules in working set
_mt_module_list() {
  # Ensure modules directory exists
  mkdir -p "${MT_MODULES_DIR}"

  # Check if any modules exist
  local module_count=0
  local -a modules=()

  while IFS= read -r module_link; do
    [[ -L "$module_link" ]] || continue
    local module_name=$(basename "$module_link")
    local target=$(readlink -f "$module_link" 2>/dev/null)
    local status="✓"

    # Check if symlink is broken
    if [[ -z "$target" ]] || [[ ! -d "$target" ]]; then
      status="✗"
      target="${target:-broken}"
    fi

    modules+=("${status}\t${module_name}\t${target}")
    ((module_count++))
  done < <(find "${MT_MODULES_DIR}" -maxdepth 1 -type l 2>/dev/null | sort)

  if [[ $module_count -eq 0 ]]; then
    _mt_info "No modules in working set"
    _mt_info "Add modules with: mt module add <module>"
    return 0
  fi

  # Output header
  printf "%-3s %-30s %s\n" "" "MODULE" "PATH"
  printf "%-3s %-30s %s\n" "---" "------" "----"

  # Output modules
  for module_info in "${modules[@]}"; do
    echo -e "$module_info"
  done | column -t -s $'\t'

  echo
  _mt_info "Total modules: $module_count"
}

# Add module to working set (clone if needed)
_mt_module_add() {
  local module_spec="$1"

  # Validate input
  if [[ -z "$module_spec" ]]; then
    _mt_error "Usage: mt module add <module>"
    _mt_info "Examples:"
    _mt_info "  mt module add owner/repo"
    _mt_info "  mt module add git@github.com:owner/repo.git"
    _mt_info "  mt module add https://github.com/owner/repo.git"
    return 1
  fi

  # Resolve to full git URL using existing function
  local git_url
  git_url=$(_mt_repo_url "$module_spec") || {
    _mt_error "Invalid module specification: $module_spec"
    return 1
  }

  _mt_debug "Resolved URL: $git_url"

  # Get canonical repository path
  local repo_path
  repo_path=$(_mt_repo_dir "$git_url") || {
    _mt_error "Failed to determine repository path"
    return 1
  }

  _mt_debug "Repository path: $repo_path"

  # Extract module name (repo basename)
  local module_name
  module_name=$(basename "$repo_path")

  # Check if already in working set
  local working_set_link="${MT_MODULES_DIR}/${module_name}"
  if [[ -L "$working_set_link" ]]; then
    local existing_target
    existing_target=$(readlink -f "$working_set_link" 2>/dev/null)

    if [[ "$existing_target" == "$repo_path" ]]; then
      _mt_info "Module already in working set: $module_name"
      return 0
    else
      _mt_error "Module name conflict: $module_name already links to different location"
      _mt_info "Existing: $existing_target"
      _mt_info "Requested: $repo_path"
      return 1
    fi
  fi

  # Clone repository if it doesn't exist
  if [[ ! -d "$repo_path/.git" ]]; then
    _mt_info "Cloning module: $git_url"
    _mt_clone "$module_spec" || {
      _mt_error "Failed to clone repository"
      return 1
    }
  else
    _mt_info "Module repository exists: $repo_path"
  fi

  # Create symlink in working set
  _mt_info "Adding module to working set: $module_name"
  if _mt_create_relative_symlink "$repo_path" "$working_set_link"; then
    _mt_info "✓ Module added: $module_name"
    _mt_info "List packages with: mt package list $module_name/*"
    return 0
  else
    _mt_error "Failed to create symlink"
    return 1
  fi
}

# Remove module from working set
_mt_module_remove() {
  local module_name="$1"

  # Validate input
  if [[ -z "$module_name" ]]; then
    _mt_error "Usage: mt module remove <module>"
    return 1
  fi

  local working_set_link="${MT_MODULES_DIR}/${module_name}"

  # Check if module is in working set
  if [[ ! -L "$working_set_link" ]]; then
    if [[ -e "$working_set_link" ]]; then
      _mt_error "Not a symlink: $working_set_link"
      return 1
    else
      _mt_error "Module not found in working set: $module_name"
      return 1
    fi
  fi

  # Get target for informational purposes
  local target
  target=$(readlink -f "$working_set_link" 2>/dev/null || echo "unknown")

  # Check if any packages from this module are in package working set
  local -a packages_using_module=()
  if [[ -d "${MT_PACKAGES_DIR}" ]]; then
    while IFS= read -r pkg_link; do
      [[ -L "$pkg_link" ]] || continue
      local pkg_target
      pkg_target=$(readlink -f "$pkg_link" 2>/dev/null) || continue

      # Check if package target is under this module
      if [[ "$pkg_target" == "$target"/* ]]; then
        packages_using_module+=("$(basename "$pkg_link")")
      fi
    done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null)
  fi

  # Warn if packages are using this module
  if [[ ${#packages_using_module[@]} -gt 0 ]]; then
    _mt_warn "The following packages from this module are in your package working set:"
    for pkg in "${packages_using_module[@]}"; do
      _mt_warn "  - $pkg"
    done
    _mt_warn "Remove these packages first with: mt package remove <package>"
    echo

    # Prompt for confirmation
    echo -n "Remove module anyway? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      _mt_info "Cancelled"
      return 0
    fi
  fi

  # Remove symlink
  if rm "$working_set_link"; then
    _mt_info "✓ Module removed from working set: $module_name"
    _mt_info "Repository preserved at: $target"
    return 0
  else
    _mt_error "Failed to remove symlink"
    return 1
  fi
}

# Edit module in editor
_mt_module_edit() {
  local module_name="$1"

  # Validate input
  if [[ -z "$module_name" ]]; then
    _mt_error "Usage: mt module edit <module>"
    return 1
  fi

  local working_set_link="${MT_MODULES_DIR}/${module_name}"

  # Check if module exists
  if [[ ! -L "$working_set_link" ]]; then
    _mt_error "Module not found in working set: $module_name"
    return 1
  fi

  # Get target path
  local target
  target=$(readlink -f "$working_set_link" 2>/dev/null)

  if [[ -z "$target" ]] || [[ ! -d "$target" ]]; then
    _mt_error "Module symlink is broken: $module_name"
    return 1
  fi

  # Open in editor
  local editor="${EDITOR:-vim}"
  _mt_info "Opening module in $editor: $module_name"
  "$editor" "$target"
}

# Main module command dispatcher
_mt_module() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    list)
      _mt_module_list "$@"
      ;;
    add)
      _mt_module_add "$@"
      ;;
    remove)
      _mt_module_remove "$@"
      ;;
    edit)
      _mt_module_edit "$@"
      ;;
    -h|--help|"")
      cat <<EOF
Usage: mt module <command> [options]

Manage metool modules in working set.

Commands:
  list                List modules in working set
  add <module>        Add module to working set (clone if needed)
  remove <module>     Remove module from working set
  edit <module>       Open module in editor

Examples:
  mt module list
  mt module add owner/repo
  mt module add https://github.com/owner/repo.git
  mt module remove metool-packages

EOF
      return 0
      ;;
    *)
      _mt_error "Unknown module command: $subcommand"
      _mt_info "Run 'mt module --help' for usage"
      return 1
      ;;
  esac
}
