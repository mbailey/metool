#!/usr/bin/env bash
# module.sh - Module management commands (MT-11)

# Get module names from working set (for completion)
# Returns one module name per line
_mt_get_working_set_modules() {
  mkdir -p "${MT_MODULES_DIR}"

  find "${MT_MODULES_DIR}" -maxdepth 1 -type l 2>/dev/null | while IFS= read -r module_link; do
    [[ -L "$module_link" ]] || continue
    basename "$module_link"
  done | sort
}

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
    _mt_warning "The following packages from this module are in your package working set:"
    for pkg in "${packages_using_module[@]}"; do
      _mt_warning "  - $pkg"
    done
    _mt_warning "Remove these packages first with: mt package remove <package>"
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

# Update module(s) from git
_mt_module_update() {
  local update_all=false
  local -a modules_to_update=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--all)
        update_all=true
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage: mt module update [OPTIONS] [MODULE...]

Update module(s) from git remote.

Options:
  -a, --all           Update all modules
  -h, --help          Show this help

Arguments:
  MODULE              Module name(s) to update

Examples:
  mt module update metool-packages
  mt module update metool-packages metool-packages-dev
  mt module update --all

EOF
        return 0
        ;;
      -*)
        _mt_error "Unknown option: $1"
        _mt_info "Run 'mt module update --help' for usage"
        return 1
        ;;
      *)
        modules_to_update+=("$1")
        shift
        ;;
    esac
  done

  # Determine which modules to update
  if [[ "$update_all" == true ]]; then
    # Get all modules from working set
    while IFS= read -r module_link; do
      [[ -L "$module_link" ]] || continue
      modules_to_update+=("$(basename "$module_link")")
    done < <(find "${MT_MODULES_DIR}" -maxdepth 1 -type l 2>/dev/null | sort)

    if [[ ${#modules_to_update[@]} -eq 0 ]]; then
      _mt_info "No modules in working set to update"
      return 0
    fi
  elif [[ ${#modules_to_update[@]} -eq 0 ]]; then
    _mt_error "Usage: mt module update [OPTIONS] [MODULE...]"
    _mt_info "Specify module name(s) or use --all to update all modules"
    _mt_info "Run 'mt module update --help' for more information"
    return 1
  fi

  # Update each module
  local updated_count=0
  local failed_count=0
  local -a failed_modules=()

  for module_name in "${modules_to_update[@]}"; do
    local working_set_link="${MT_MODULES_DIR}/${module_name}"

    # Check if module exists in working set
    if [[ ! -L "$working_set_link" ]]; then
      _mt_error "Module not in working set: $module_name"
      ((failed_count++))
      failed_modules+=("$module_name")
      continue
    fi

    # Get target path
    local target
    target=$(readlink -f "$working_set_link" 2>/dev/null)

    if [[ -z "$target" ]] || [[ ! -d "$target" ]]; then
      _mt_error "Module symlink is broken: $module_name"
      ((failed_count++))
      failed_modules+=("$module_name")
      continue
    fi

    # Check if it's a git repository
    if [[ ! -d "$target/.git" ]]; then
      _mt_error "Not a git repository: $module_name ($target)"
      ((failed_count++))
      failed_modules+=("$module_name")
      continue
    fi

    # Update the module
    _mt_info "Updating module: $module_name"

    # Get current branch and check for uncommitted changes
    local current_branch
    current_branch=$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)

    if [[ -n $(git -C "$target" status --porcelain 2>/dev/null) ]]; then
      _mt_warning "  Uncommitted changes detected, skipping: $module_name"
      ((failed_count++))
      failed_modules+=("$module_name (uncommitted changes)")
      continue
    fi

    # Pull changes
    _mt_debug "  Running: git -C $target pull"
    if git -C "$target" pull 2>&1 | sed 's/^/  /'; then
      _mt_info "  ✓ Updated: $module_name"
      ((updated_count++))
    else
      _mt_error "  Failed to update: $module_name"
      ((failed_count++))
      failed_modules+=("$module_name")
    fi
  done

  # Summary
  echo
  if [[ $updated_count -gt 0 ]]; then
    _mt_info "✓ Updated $updated_count module(s)"
  fi

  if [[ $failed_count -gt 0 ]]; then
    _mt_warning "Failed to update $failed_count module(s):"
    for failed_module in "${failed_modules[@]}"; do
      _mt_warning "  - $failed_module"
    done
    return 1
  fi

  return 0
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
    update)
      _mt_module_update "$@"
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
  update [MODULE...]  Update module(s) from git remote

Examples:
  mt module list
  mt module add owner/repo
  mt module add https://github.com/owner/repo.git
  mt module remove metool-packages
  mt module update metool-packages
  mt module update --all

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
