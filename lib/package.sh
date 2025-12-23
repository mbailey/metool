#!/usr/bin/env bash
# Functions for package creation and management

# Get package names from working set (for completion)
# Returns one package name per line
_mt_get_working_set_packages() {
  mkdir -p "${MT_PACKAGES_DIR}"

  find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null | while IFS= read -r package_link; do
    [[ -L "$package_link" ]] || continue
    basename "$package_link"
  done | sort
}

# List packages in working set
_mt_package_list() {
  # Ensure packages directory exists
  mkdir -p "${MT_PACKAGES_DIR}"

  # Check if any packages exist
  local package_count=0
  local -a packages=()

  while IFS= read -r package_link; do
    [[ -L "$package_link" ]] || continue
    local package_name=$(basename "$package_link")
    local target=$(readlink -f "$package_link" 2>/dev/null)
    local status="✓"

    # Check if symlink is broken
    if [[ -z "$target" ]] || [[ ! -d "$target" ]]; then
      status="✗"
      target="${target:-broken}"
    fi

    packages+=("${status}\t${package_name}\t${target}")
    ((package_count++))
  done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null | sort)

  if [[ $package_count -eq 0 ]]; then
    _mt_info "No packages in working set"
    _mt_info "Add packages with: mt package add <module>/<package>"
    return 0
  fi

  # Output header
  printf "%-3s %-30s %s\n" "" "PACKAGE" "PATH"
  printf "%-3s %-30s %s\n" "---" "-------" "----"

  # Output packages
  for package_info in "${packages[@]}"; do
    echo -e "$package_info"
  done | column -t -s $'\t'

  echo
  _mt_info "Total packages: $package_count"
}

# Add single package to working set (internal function)
_mt_package_add_single() {
  local package_spec="$1"
  local module_name=""
  local package_name=""

  # Smart parsing: handle both module/package format and filesystem paths
  # Strip common path prefixes to get module/package format
  package_spec="${package_spec#./}"                           # Remove leading ./
  package_spec="${package_spec#$MT_MODULES_DIR/}"            # Remove ~/.metool/modules/
  package_spec="${package_spec#${HOME}/.metool/modules/}"    # Remove /home/user/.metool/modules/
  package_spec="${package_spec#modules/}"                     # Remove modules/

  # Now parse module/package format
  if [[ ! "$package_spec" =~ ^([^/]+)/([^/]+)$ ]]; then
    _mt_error "Invalid format: $package_spec (use: <module>/<package>)"
    _mt_info "Examples: dev/agents, metool-packages/git-tools, or dev/*"
    return 1
  fi

  module_name="${BASH_REMATCH[1]}"
  package_name="${BASH_REMATCH[2]}"

  # Check if module is in working set
  if ! _mt_module_in_working_set "$module_name"; then
    _mt_error "Module not in working set: $module_name"
    _mt_info "Add module first: mt module add $module_name"
    return 1
  fi

  # Get module path
  local module_path
  module_path=$(_mt_module_path "$module_name") || {
    _mt_error "Module symlink is broken: $module_name"
    return 1
  }

  # Check if package exists in module
  local package_path="${module_path}/${package_name}"
  if [[ ! -d "$package_path" ]]; then
    _mt_error "Package not found: $module_name/$package_name"
    return 1
  fi

  # Check if already in working set
  local working_set_link="${MT_PACKAGES_DIR}/${package_name}"
  if [[ -L "$working_set_link" ]]; then
    local existing_target
    existing_target=$(readlink -f "$working_set_link" 2>/dev/null)

    if [[ "$existing_target" == "$package_path" ]]; then
      _mt_info "Package already in working set: $package_name"
      return 0
    else
      _mt_error "Package name conflict: $package_name already links to different location"
      _mt_info "Existing: $existing_target"
      _mt_info "Requested: $package_path"
      return 1
    fi
  fi

  # Create symlink in working set
  _mt_info "Adding package to working set: $package_name"
  if _mt_create_relative_symlink "$package_path" "$working_set_link"; then
    _mt_info "✓ Package added: $package_name"
    return 0
  else
    _mt_error "Failed to create symlink"
    return 1
  fi
}

# Add package(s) to working set (supports multiple packages and globs)
_mt_package_add() {
  # Validate input
  if [[ $# -eq 0 ]]; then
    _mt_error "Usage: mt package add <module>/<package> [<module>/<package>...]"
    _mt_info "Examples:"
    _mt_info "  mt package add metool-packages/git-tools"
    _mt_info "  mt package add dev/tool1 dev/tool2"
    _mt_info "  mt package add dev/*"
    return 1
  fi

  local success_count=0
  local fail_count=0
  local skip_count=0

  # Process each package spec
  for package_spec in "$@"; do
    if _mt_package_add_single "$package_spec"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  done

  # Summary for multiple packages
  if [[ $# -gt 1 ]]; then
    echo
    _mt_info "Summary: $success_count added, $fail_count failed"
    if [[ $success_count -gt 0 ]]; then
      _mt_info "Install with: mt package install <package>"
    fi
  fi

  # Return success if at least one package was added
  [[ $success_count -gt 0 ]]
}

# Remove package from working set
_mt_package_remove() {
  local package_name="$1"

  # Validate input
  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package remove <package>"
    return 1
  fi

  local working_set_link="${MT_PACKAGES_DIR}/${package_name}"

  # Check if package is in working set
  if [[ ! -L "$working_set_link" ]]; then
    if [[ -e "$working_set_link" ]]; then
      _mt_error "Not a symlink: $working_set_link"
      return 1
    else
      _mt_error "Package not found in working set: $package_name"
      return 1
    fi
  fi

  # Get target for informational purposes
  local target
  target=$(readlink -f "$working_set_link" 2>/dev/null || echo "unknown")

  # Check if package is installed
  if _mt_package_is_installed "$package_name"; then
    _mt_warning "Package is currently installed (stowed)"
    _mt_warning "Removing from working set will not unstow it"
    _mt_info "To unstow: cd to package and run 'stow -D .' or use mt doctor --fix"
    echo

    # Prompt for confirmation
    echo -n "Remove from working set anyway? [y/N] "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      _mt_info "Cancelled"
      return 0
    fi
  fi

  # Remove symlink
  if rm "$working_set_link"; then
    _mt_info "✓ Package removed from working set: $package_name"
    if _mt_package_is_installed "$package_name" 2>/dev/null; then
      _mt_info "Package is still installed. Run 'mt doctor' to check for orphaned symlinks."
    fi
    return 0
  else
    _mt_error "Failed to remove symlink"
    return 1
  fi
}

# Edit package in editor
_mt_package_edit() {
  local package_name="$1"

  # Validate input
  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package edit <package>"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  # Get target path
  local target
  target=$(_mt_package_path "$package_name")

  if [[ -z "$target" ]] || [[ ! -d "$target" ]]; then
    _mt_error "Package symlink is broken: $package_name"
    return 1
  fi

  # Open in editor
  local editor="${EDITOR:-vim}"
  _mt_info "Opening package in $editor: $package_name"
  "$editor" "$target"
}

# Install single package from working set (internal function)
_mt_package_install_single() {
  local package_name="$1"
  local skip_bin="$2"
  local skip_config="$3"
  local skip_shell="$4"
  local skip_skill="$5"

  # Check if package is in working set
  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    _mt_info "Add package first: mt package add <module>/$package_name"
    return 1
  fi

  # Get package path
  local package_path
  package_path=$(_mt_package_path "$package_name") || {
    _mt_error "Package symlink is broken: $package_name"
    return 1
  }

  if [[ -z "$package_path" ]] || [[ ! -d "$package_path" ]]; then
    _mt_error "Package directory not found: $package_path"
    return 1
  fi

  if [[ "$skip_bin" == "true" ]] || [[ "$skip_config" == "true" ]] || [[ "$skip_shell" == "true" ]] || [[ "$skip_skill" == "true" ]]; then
    # With exclusions, we need to handle each component separately
    local installed_components=()
    local skipped_components=()

    # Install bin/ unless skipped
    if [[ "$skip_bin" != "true" ]] && [[ -d "$package_path/bin" ]]; then
      if command stow --dir="$package_path" --target="${MT_PKG_DIR}/bin" bin 2>&1; then
        installed_components+=("bin")
      else
        _mt_error "Failed to install bin component"
        return 1
      fi
    elif [[ "$skip_bin" == "true" ]] && [[ -d "$package_path/bin" ]]; then
      skipped_components+=("bin")
    fi

    # Install config/ unless skipped
    if [[ "$skip_config" != "true" ]] && [[ -d "$package_path/config" ]]; then
      mkdir -p "${MT_PKG_DIR}/config/${package_name}"
      if command stow --dir="$package_path" --target="${MT_PKG_DIR}/config/${package_name}" config 2>&1; then
        if command stow --dir="${MT_PKG_DIR}/config" --target="${HOME}" --dotfiles "${package_name}" 2>&1; then
          installed_components+=("config")
        else
          _mt_error "Failed to link config to home"
          return 1
        fi
      else
        _mt_error "Failed to install config component"
        return 1
      fi
    elif [[ "$skip_config" == "true" ]] && [[ -d "$package_path/config" ]]; then
      skipped_components+=("config")
    fi

    # Install shell/ unless skipped
    if [[ "$skip_shell" != "true" ]] && [[ -d "$package_path/shell" ]]; then
      mkdir -p "${MT_PKG_DIR}/shell/${package_name}"
      if command stow --dir="$package_path" --target="${MT_PKG_DIR}/shell/${package_name}" shell 2>&1; then
        installed_components+=("shell")
      else
        _mt_error "Failed to install shell component"
        return 1
      fi
    elif [[ "$skip_shell" == "true" ]] && [[ -d "$package_path/shell" ]]; then
      skipped_components+=("shell")
    fi

    # Install SKILL.md unless skipped
    if [[ "$skip_skill" != "true" ]] && [[ -f "$package_path/SKILL.md" ]]; then
      mkdir -p "${MT_PKG_DIR}/skills"
      local skills_target="${MT_PKG_DIR}/skills/${package_name}"
      [[ -L "$skills_target" ]] && rm "$skills_target"

      if ln -s "${package_path}" "$skills_target"; then
        mkdir -p "${HOME}/.claude/skills"
        local claude_skill_link="${HOME}/.claude/skills/${package_name}"
        [[ -L "$claude_skill_link" ]] && rm "$claude_skill_link"

        if ln -s "$skills_target" "$claude_skill_link"; then
          installed_components+=("skill")
        else
          _mt_warning "Failed to create Claude Code skill symlink for ${package_name}"
        fi
      else
        _mt_error "Failed to create metool skill symlink"
        return 1
      fi
    elif [[ "$skip_skill" == "true" ]] && [[ -f "$package_path/SKILL.md" ]]; then
      skipped_components+=("skill")
    fi

    if [[ ${#installed_components[@]} -gt 0 ]] || [[ ${#skipped_components[@]} -eq 0 ]]; then
      # Show success if components installed OR nothing skipped (shouldn't happen but safety)
      _mt_info "✓ Installed: $package_name"
    fi
    if [[ ${#skipped_components[@]} -gt 0 ]]; then
      _mt_info "  Skipped: ${skipped_components[*]}"
    fi

  else
    # No exclusions - use standard stow function
    _mt_stow "$package_path" || return 1
  fi

  # Check if package has services
  if _mt_package_has_services "$package_name"; then
    _mt_info "→ Includes services: mt package service $package_name <start|stop|status|enable|disable>"
  fi

  return 0
}

# Install package(s) from working set (supports multiple packages)
_mt_package_install() {
  # Parse options and package names
  local skip_bin=false
  local skip_config=false
  local skip_shell=false
  local skip_skill=false
  local -a package_names=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --no-bin)
        skip_bin=true
        shift
        ;;
      --no-config)
        skip_config=true
        shift
        ;;
      --no-shell)
        skip_shell=true
        shift
        ;;
      --no-skill)
        skip_skill=true
        shift
        ;;
      -*)
        _mt_error "Unknown option: $1"
        return 1
        ;;
      *)
        package_names+=("$1")
        shift
        ;;
    esac
  done

  # Validate input
  if [[ ${#package_names[@]} -eq 0 ]]; then
    _mt_error "Usage: mt package install <package> [<package>...] [options]"
    _mt_info "Options:"
    _mt_info "  --no-bin      Skip installing bin/ directory"
    _mt_info "  --no-config   Skip installing config/ directory"
    _mt_info "  --no-shell    Skip installing shell/ directory"
    _mt_info "  --no-skill    Skip installing SKILL.md"
    _mt_info ""
    _mt_info "Examples:"
    _mt_info "  mt package install git-tools"
    _mt_info "  mt package install agents tmux vim-config"
    _mt_info "  mt package install --no-config tool1 tool2"
    return 1
  fi

  local success_count=0
  local fail_count=0
  local -a failed_packages=()

  # Install each package
  for package_name in "${package_names[@]}"; do
    if _mt_package_install_single "$package_name" "$skip_bin" "$skip_config" "$skip_shell" "$skip_skill"; then
      ((success_count++))
    else
      ((fail_count++))
      failed_packages+=("$package_name")
    fi
  done

  # Summary for multiple packages
  if [[ ${#package_names[@]} -gt 1 ]]; then
    echo
    _mt_info "Summary: $success_count installed, $fail_count failed"

    # Show failed packages if any
    if [[ $fail_count -gt 0 ]]; then
      echo
      _mt_error "Failed packages:"
      for pkg in "${failed_packages[@]}"; do
        echo "  - $pkg"
      done
    fi
  fi

  # Return success if at least one package was installed
  [[ $success_count -gt 0 ]]
}

# Uninstall single package (remove stow symlinks) - internal function
_mt_package_uninstall_single() {
  local package_name="$1"
  local skip_bin="$2"
  local skip_config="$3"
  local skip_shell="$4"
  local skip_skill="$5"

  # Check if package is in working set
  if ! _mt_package_in_working_set "$package_name"; then
    _mt_warning "Package not in working set: $package_name"
    _mt_info "Checking if package is installed anyway..."
  fi

  # Get package path
  local package_path
  package_path=$(_mt_package_path "$package_name" 2>/dev/null)

  if [[ -z "$package_path" ]] || [[ ! -d "$package_path" ]]; then
    _mt_error "Cannot locate package directory for: $package_name"
    _mt_info "This may indicate orphaned symlinks. Run 'mt doctor' to diagnose."
    return 1
  fi

  # Check if package is actually installed
  if ! _mt_package_is_installed "$package_name"; then
    _mt_info "Package is not installed: $package_name"
    return 0
  fi

  local uninstalled_components=()
  local skipped_components=()

  # Uninstall bin/ unless skipped
  if [[ "$skip_bin" != "true" ]] && [[ -d "$package_path/bin" ]]; then
    if command stow -D --dir="$package_path" --target="${MT_PKG_DIR}/bin" bin 2>&1; then
      uninstalled_components+=("bin")
    else
      _mt_warning "Failed to uninstall bin component (may not have been installed)"
    fi
  elif [[ "$skip_bin" == "true" ]] && [[ -d "$package_path/bin" ]]; then
    skipped_components+=("bin")
  fi

  # Uninstall config/ unless skipped
  if [[ "$skip_config" != "true" ]] && [[ -d "$package_path/config" ]]; then
    # First unstow from home
    if command stow -D --dir="${MT_PKG_DIR}/config" --target="${HOME}" --dotfiles "${package_name}" 2>&1; then
      # Then unstow from metool config dir
      if command stow -D --dir="$package_path" --target="${MT_PKG_DIR}/config/${package_name}" config 2>&1; then
        uninstalled_components+=("config")
        # Clean up empty metool config directory
        rmdir "${MT_PKG_DIR}/config/${package_name}" 2>/dev/null || true
      else
        _mt_warning "Failed to uninstall config component from metool"
      fi
    else
      _mt_warning "Failed to uninstall config component from home"
    fi
  elif [[ "$skip_config" == "true" ]] && [[ -d "$package_path/config" ]]; then
    skipped_components+=("config")
  fi

  # Uninstall shell/ unless skipped
  if [[ "$skip_shell" != "true" ]] && [[ -d "$package_path/shell" ]]; then
    if command stow -D --dir="$package_path" --target="${MT_PKG_DIR}/shell/${package_name}" shell 2>&1; then
      uninstalled_components+=("shell")
      # Clean up empty metool shell directory
      rmdir "${MT_PKG_DIR}/shell/${package_name}" 2>/dev/null || true
    else
      _mt_warning "Failed to uninstall shell component"
    fi
  elif [[ "$skip_shell" == "true" ]] && [[ -d "$package_path/shell" ]]; then
    skipped_components+=("shell")
  fi

  # Uninstall SKILL.md symlinks unless skipped
  if [[ "$skip_skill" != "true" ]] && [[ -f "$package_path/SKILL.md" ]]; then
    local claude_skill_link="${HOME}/.claude/skills/${package_name}"
    local skills_target="${MT_PKG_DIR}/skills/${package_name}"

    # Remove Claude Code symlink
    if [[ -L "$claude_skill_link" ]]; then
      rm "$claude_skill_link"
      uninstalled_components+=("skill")
    fi

    # Remove metool skills symlink
    if [[ -L "$skills_target" ]]; then
      rm "$skills_target"
    fi

    # Clean up empty metool skills directory
    rmdir "${MT_PKG_DIR}/skills" 2>/dev/null || true
  elif [[ "$skip_skill" == "true" ]] && [[ -f "$package_path/SKILL.md" ]]; then
    skipped_components+=("skill")
  fi

  if [[ ${#uninstalled_components[@]} -gt 0 ]] || [[ ${#skipped_components[@]} -eq 0 ]]; then
    # Show success message if components were uninstalled OR if nothing was skipped (standard case)
    _mt_info "✓ Uninstalled: $package_name"
  fi

  if [[ ${#skipped_components[@]} -gt 0 ]]; then
    _mt_info "  Skipped: ${skipped_components[*]}"
  fi

  return 0
}

# Uninstall package(s) from working set (supports multiple packages)
_mt_package_uninstall() {
  # Parse options and package names
  local skip_bin=false
  local skip_config=false
  local skip_shell=false
  local skip_skill=false
  local -a package_names=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --no-bin)
        skip_bin=true
        shift
        ;;
      --no-config)
        skip_config=true
        shift
        ;;
      --no-shell)
        skip_shell=true
        shift
        ;;
      --no-skill)
        skip_skill=true
        shift
        ;;
      -*)
        _mt_error "Unknown option: $1"
        return 1
        ;;
      *)
        package_names+=("$1")
        shift
        ;;
    esac
  done

  # Validate input
  if [[ ${#package_names[@]} -eq 0 ]]; then
    _mt_error "Usage: mt package uninstall <package> [<package>...] [options]"
    _mt_info "Options:"
    _mt_info "  --no-bin      Skip uninstalling bin/ directory"
    _mt_info "  --no-config   Skip uninstalling config/ directory"
    _mt_info "  --no-shell    Skip uninstalling shell/ directory"
    _mt_info "  --no-skill    Skip uninstalling SKILL.md"
    _mt_info ""
    _mt_info "Examples:"
    _mt_info "  mt package uninstall git-tools"
    _mt_info "  mt package uninstall agents tmux vim-config"
    _mt_info "  mt package uninstall --no-config tool1 tool2"
    return 1
  fi

  local success_count=0
  local fail_count=0
  local -a failed_packages=()

  # Uninstall each package
  for package_name in "${package_names[@]}"; do
    if _mt_package_uninstall_single "$package_name" "$skip_bin" "$skip_config" "$skip_shell" "$skip_skill"; then
      ((success_count++))
    else
      ((fail_count++))
      failed_packages+=("$package_name")
    fi
  done

  # Summary for multiple packages
  if [[ ${#package_names[@]} -gt 1 ]]; then
    echo
    _mt_info "Summary: $success_count uninstalled, $fail_count failed"

    # Show failed packages if any
    if [[ $fail_count -gt 0 ]]; then
      echo
      _mt_error "Failed packages:"
      for pkg in "${failed_packages[@]}"; do
        echo "  - $pkg"
      done
    fi
  fi

  # Return success if at least one package was uninstalled
  [[ $success_count -gt 0 ]]
}

# Main package command dispatcher
_mt_package() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    list)
      _mt_package_list "$@"
      ;;
    add)
      _mt_package_add "$@"
      ;;
    remove)
      _mt_package_remove "$@"
      ;;
    edit)
      _mt_package_edit "$@"
      ;;
    install)
      _mt_package_install "$@"
      ;;
    uninstall)
      _mt_package_uninstall "$@"
      ;;
    service)
      _mt_service "$@"
      ;;
    new)
      _mt_package_new "$@"
      ;;
    validate)
      _mt_package_validate "$@"
      ;;
    diff)
      _mt_package_diff "$@"
      ;;
    -h|--help|"")
      cat <<EOF
Usage: mt package <command> [options]

Manage metool packages in working set.

Commands:
  list                           List packages in working set
  add <mod>/<pkg>...             Add package(s) to working set
  remove <package>               Remove package from working set
  edit <package>                 Open package in editor
  install <package>... [opts]    Install package(s) using stow
  uninstall <package>... [opts]  Uninstall package(s) (remove symlinks)
  service <cmd> <package>        Manage package services (systemd/launchd)
  new NAME [PATH]                Create a new package from template
  validate <package|path>        Validate package structure and SKILL.md
  diff <pkg> <from> <to>         Compare package between modules

Install/Uninstall Options:
  --no-bin      Skip bin/ directory
  --no-config   Skip config/ directory
  --no-shell    Skip shell/ directory

Service Commands:
  list, start, stop, restart, status, enable, disable, logs
  Run 'mt package service --help' for details

Examples:
  mt package list
  mt package add metool-packages/git-tools
  mt package add dev/tool1 dev/tool2        # Add multiple packages
  mt package add dev/*                      # Add all packages from module
  mt package install git-tools
  mt package install agents tmux vim-config # Install multiple packages
  mt package install vim-config --no-bin --no-shell
  mt package uninstall agents tmux          # Uninstall multiple packages
  mt package service start prometheus
  mt package service logs prometheus -f
  mt package remove git-tools
  mt package edit git-tools
  mt package diff tmux dev pub           # Compare package between modules
  mt package diff tmux dev pub --content # Show detailed content diff

Note: 'remove' removes from working set, 'uninstall' removes stow symlinks

EOF
      return 0
      ;;
    *)
      _mt_error "Unknown package command: $subcommand"
      _mt_info "Run 'mt package --help' for usage"
      return 1
      ;;
  esac
}

# Create a new package from template
_mt_package_new() {
  local package_name=""
  local target_path=""
  local module_name=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        cat << EOF
Create a new metool package from template

Usage: mt package new NAME [PATH]

Arguments:
  NAME              Package name (lowercase-with-hyphens)
  PATH              Target directory (default: current directory)

Options:
  -h, --help        Show this help message

The command will create a new package directory with:
  - README.md with TODO placeholders
  - SKILL.md.example for Claude Code integration
  - bin/ with example executable
  - shell/ with functions and aliases
  - config/ with example configuration
  - lib/ with helper functions

Examples:
  mt package new my-tools              # Create in current directory
  mt package new my-tools ~/packages   # Create in ~/packages
  mt package new dev-helpers .         # Create in current directory

After creation:
  1. Edit README.md and fill in TODO items
  2. Optionally rename SKILL.md.example to SKILL.md and customize
  3. Add your executables to bin/
  4. Add shell functions to shell/functions
  5. Install with: mt install <module>/my-tools

EOF
        return 0
        ;;
      -*)
        _mt_error "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$package_name" ]]; then
          package_name="$1"
        elif [[ -z "$target_path" ]]; then
          target_path="$1"
        else
          _mt_error "Too many arguments"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate package name
  if [[ -z "$package_name" ]]; then
    _mt_error "Package name is required"
    echo "Usage: mt package new NAME [PATH]"
    return 1
  fi

  # Validate package name format (lowercase with hyphens)
  if ! [[ "$package_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    _mt_error "Invalid package name: $package_name"
    echo "Package name must be lowercase with hyphens (e.g., my-package)"
    return 1
  fi

  # Default to current directory if no path provided
  if [[ -z "$target_path" ]]; then
    target_path="."
  fi

  # Resolve target path
  target_path="$(realpath "$target_path")"
  local package_dir="${target_path}/${package_name}"

  # Check if package directory already exists
  if [[ -d "$package_dir" ]]; then
    _mt_error "Package directory already exists: $package_dir"
    return 1
  fi

  # Template directory
  local template_dir="${MT_ROOT}/templates/package"

  if [[ ! -d "$template_dir" ]]; then
    _mt_error "Template directory not found: $template_dir"
    return 1
  fi

  # Create package directory
  _mt_log INFO "Creating package: $package_name"
  _mt_log INFO "Location: $package_dir"
  echo ""

  mkdir -p "$package_dir"

  # Copy template files and replace placeholders
  _mt_package_copy_template "$template_dir" "$package_dir" "$package_name"

  # Make bin scripts executable
  if [[ -d "$package_dir/bin" ]]; then
    find "$package_dir/bin" -type f -exec chmod +x {} \;
  fi

  echo ""
  _mt_log INFO "✅ Package '$package_name' created successfully"
  echo ""
  echo "Next steps:"
  echo "  1. cd $package_dir"
  echo "  2. Edit README.md and complete TODO items"
  echo "  3. Optionally rename SKILL.md.example to SKILL.md and customize"
  echo "  4. Add your code to bin/, shell/, config/, or lib/"
  echo "  5. Install with: mt install <module>/$package_name"
  echo ""
}

# Validate package structure and SKILL.md
_mt_package_validate() {
  local package_spec="$1"
  local package_path=""
  local package_name=""
  local errors=()
  local warnings=()

  # Show help if no argument
  if [[ -z "$package_spec" ]] || [[ "$package_spec" == "-h" ]] || [[ "$package_spec" == "--help" ]]; then
    cat <<EOF
Validate package structure and SKILL.md

Usage: mt package validate <package|path>

Validates:
  - README.md exists (required)
  - SKILL.md structure if present (frontmatter, name, description)
  - Executable permissions in bin/
  - Package naming conventions

Examples:
  mt package validate my-package         # Package in working set
  mt package validate ./path/to/package  # Package by path
  mt package validate .                  # Current directory

EOF
    return 0
  fi

  # Resolve package path
  if [[ -d "$package_spec" ]]; then
    # Direct path provided
    package_path="$(cd "$package_spec" && pwd)"
    package_name="$(basename "$package_path")"
  elif [[ -L "${MT_PACKAGES_DIR}/${package_spec}" ]]; then
    # Package in working set
    package_path="$(readlink -f "${MT_PACKAGES_DIR}/${package_spec}")"
    package_name="$package_spec"
  else
    _mt_error "Package not found: $package_spec"
    _mt_info "Provide a path or package name from working set"
    return 1
  fi

  if [[ ! -d "$package_path" ]]; then
    _mt_error "Package directory not found: $package_path"
    return 1
  fi

  echo "Validating package: $package_name"
  echo "Path: $package_path"
  echo ""

  # Check README.md (required)
  if [[ ! -f "$package_path/README.md" ]]; then
    errors+=("README.md not found (required for metool packages)")
  fi

  # Check bin/ executables
  if [[ -d "$package_path/bin" ]]; then
    while IFS= read -r -d '' script; do
      if [[ ! -x "$script" ]]; then
        warnings+=("Not executable: bin/$(basename "$script")")
      fi
    done < <(find "$package_path/bin" -type f -print0 2>/dev/null)
  fi

  # Check SKILL.md if present
  if [[ -f "$package_path/SKILL.md" ]]; then
    _mt_validate_skill "$package_path" "$package_name" errors warnings
  elif [[ -f "$package_path/SKILL.md.example" ]]; then
    _mt_info "SKILL.md.example found - rename to SKILL.md to enable skill"
  fi

  # Check package name convention
  if [[ ! "$package_name" =~ ^[a-z0-9-]+$ ]]; then
    warnings+=("Package name should be hyphen-case (lowercase, digits, hyphens)")
  fi

  # Report results
  echo ""
  if [[ ${#errors[@]} -eq 0 ]] && [[ ${#warnings[@]} -eq 0 ]]; then
    _mt_log INFO "✅ Package is valid"
    return 0
  fi

  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "Warnings:"
    for warning in "${warnings[@]}"; do
      echo "  ⚠️  $warning"
    done
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "Errors:"
    for error in "${errors[@]}"; do
      echo "  ❌ $error"
    done
    return 1
  fi

  return 0
}

# Validate SKILL.md structure (internal helper)
_mt_validate_skill() {
  local package_path="$1"
  local package_name="$2"
  local -n _errors=$3
  local -n _warnings=$4
  local skill_file="$package_path/SKILL.md"

  # Read first few lines to check frontmatter
  local content
  content=$(<"$skill_file")

  # Check for YAML frontmatter
  if [[ ! "$content" =~ ^--- ]]; then
    _errors+=("SKILL.md: No YAML frontmatter (must start with ---)")
    return
  fi

  # Extract frontmatter (only the first YAML block between --- markers)
  local frontmatter
  frontmatter=$(echo "$content" | awk '/^---$/{if(++n==1)next; if(n==2)exit} n==1{print}')

  if [[ -z "$frontmatter" ]]; then
    _errors+=("SKILL.md: Invalid frontmatter format (missing closing ---)")
    return
  fi

  # Check required fields
  if ! echo "$frontmatter" | grep -q '^name:'; then
    _errors+=("SKILL.md: Missing 'name' field in frontmatter")
  else
    # Validate name format and match (get first match only)
    local skill_name
    skill_name=$(echo "$frontmatter" | grep -m1 '^name:' | sed 's/^name:[[:space:]]*//')

    if [[ ! "$skill_name" =~ ^[a-z0-9-]+$ ]]; then
      _errors+=("SKILL.md: Name '$skill_name' must be hyphen-case")
    elif [[ "$skill_name" =~ ^-|-$|-- ]]; then
      _errors+=("SKILL.md: Name cannot start/end with hyphen or have consecutive hyphens")
    elif [[ "$skill_name" != "$package_name" ]]; then
      _warnings+=("SKILL.md: Name '$skill_name' doesn't match package name '$package_name'")
    fi
  fi

  if ! echo "$frontmatter" | grep -q '^description:'; then
    _errors+=("SKILL.md: Missing 'description' field in frontmatter")
  else
    local description
    description=$(echo "$frontmatter" | grep -m1 '^description:' | sed 's/^description:[[:space:]]*//')

    # Check for TODO placeholder
    if [[ "$description" =~ \[TODO ]] || [[ "$description" =~ ^\[ ]]; then
      _errors+=("SKILL.md: Description contains TODO placeholder - please complete it")
    fi

    # Check minimum length
    if [[ ${#description} -lt 20 ]]; then
      _warnings+=("SKILL.md: Description is very short (recommend 20+ characters)")
    fi
  fi
}

# Copy template files and replace placeholders
_mt_package_copy_template() {
  local template_dir="$1"
  local package_dir="$2"
  local package_name="$3"

  # Convert package name to title case for display
  local package_title=$(echo "$package_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

  # Copy all files from template, replacing placeholders
  (cd "$template_dir" && find . -type f) | while IFS= read -r file; do
    local src="${template_dir}/${file#./}"
    local dest="${package_dir}/${file#./}"

    # Create directory if needed
    mkdir -p "$(dirname "$dest")"

    # Copy file and replace placeholders
    sed \
      -e "s/{PACKAGE_NAME}/${package_name}/g" \
      -e "s/{PACKAGE_TITLE}/${package_title}/g" \
      -e "s/{MODULE}/module/g" \
      "$src" > "$dest"

    _mt_log DEBUG "Created: ${file#./}"
  done

  # Rename package-name placeholder in config path
  if [[ -d "$package_dir/config/dot-config/package-name" ]]; then
    mv "$package_dir/config/dot-config/package-name" \
       "$package_dir/config/dot-config/$package_name"
  fi
}

# Compare package between two modules (git-tracked files only)
_mt_package_diff() {
  local package_name=""
  local from_module=""
  local to_module=""
  local show_content=false
  local quiet=false
  local include_untracked=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        cat <<EOF
Compare a package between two modules (git-tracked files only)

Usage: mt package diff <package> <from-module> <to-module> [options]

Arguments:
  package      Package name to compare
  from-module  Source module (e.g., dev)
  to-module    Target module (e.g., pub)

Options:
  -c, --content     Show file content differences (default: file list only)
  -q, --quiet       Only show if packages differ (exit code only)
  -a, --all         Include untracked files (default: git-tracked only)
  -h, --help        Show this help message

Examples:
  mt package diff tmux dev pub           # Compare tmux between dev and pub
  mt package diff tmux dev pub --content # Show full diff
  mt package diff git-tools dev pub -q   # Check if packages differ
  mt package diff tmux dev pub --all     # Include untracked files

Workflow for promoting packages:
  1. Run diff to see what differs
  2. Review differences for sensitive content
  3. Copy approved files: cp -r source/file target/file
  4. Commit changes in target module

Note: By default, only git-tracked files are compared. Use --all to include
untracked files (useful for debugging but may show temp/working files).

EOF
        return 0
        ;;
      -c|--content)
        show_content=true
        shift
        ;;
      -q|--quiet)
        quiet=true
        shift
        ;;
      -a|--all)
        include_untracked=true
        shift
        ;;
      -*)
        _mt_error "Unknown option: $1"
        return 1
        ;;
      *)
        if [[ -z "$package_name" ]]; then
          package_name="$1"
        elif [[ -z "$from_module" ]]; then
          from_module="$1"
        elif [[ -z "$to_module" ]]; then
          to_module="$1"
        else
          _mt_error "Too many arguments"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate arguments
  if [[ -z "$package_name" ]] || [[ -z "$from_module" ]] || [[ -z "$to_module" ]]; then
    _mt_error "Usage: mt package diff <package> <from-module> <to-module>"
    _mt_info "Example: mt package diff tmux dev pub"
    return 1
  fi

  # Get module paths
  local from_path="${MT_MODULES_DIR}/${from_module}"
  local to_path="${MT_MODULES_DIR}/${to_module}"

  # Check modules exist
  if [[ ! -L "$from_path" ]] || [[ ! -d "$(readlink -f "$from_path")" ]]; then
    _mt_error "Module not found in working set: $from_module"
    _mt_info "Add module with: mt module add $from_module"
    return 1
  fi

  if [[ ! -L "$to_path" ]] || [[ ! -d "$(readlink -f "$to_path")" ]]; then
    _mt_error "Module not found in working set: $to_module"
    _mt_info "Add module with: mt module add $to_module"
    return 1
  fi

  # Resolve to actual paths (module root directories)
  local from_module_root
  local to_module_root
  from_module_root="$(readlink -f "$from_path")"
  to_module_root="$(readlink -f "$to_path")"
  from_path="${from_module_root}/${package_name}"
  to_path="${to_module_root}/${package_name}"

  # Check if package exists in source
  if [[ ! -d "$from_path" ]]; then
    _mt_error "Package not found in $from_module: $package_name"
    return 1
  fi

  # Check if package exists in target
  if [[ ! -d "$to_path" ]]; then
    if [[ "$quiet" == "true" ]]; then
      return 1  # Different (target doesn't exist)
    fi
    echo "Package '$package_name' exists in $from_module but not in $to_module"
    echo ""
    echo "To create in $to_module:"
    echo "  cp -r \"$from_path\" \"$(dirname "$to_path")/\""
    return 1
  fi

  if [[ "$quiet" != "true" ]]; then
    echo "Comparing: $package_name"
    echo "  From: $from_path"
    echo "  To:   $to_path"
    if [[ "$include_untracked" != "true" ]]; then
      echo "  (git-tracked files only, use --all for everything)"
    fi
    echo ""
  fi

  # Get list of files to compare
  local from_files to_files
  if [[ "$include_untracked" == "true" ]]; then
    # All files (original behavior)
    from_files=$(cd "$from_path" && find . -type f | sed 's|^\./||' | sort)
    to_files=$(cd "$to_path" && find . -type f | sed 's|^\./||' | sort)
  else
    # Git-tracked files only
    from_files=$(cd "$from_module_root" && git ls-files "$package_name" 2>/dev/null | sed "s|^${package_name}/||" | sort)
    to_files=$(cd "$to_module_root" && git ls-files "$package_name" 2>/dev/null | sed "s|^${package_name}/||" | sort)
  fi

  # Find files only in source
  local only_in_from
  only_in_from=$(comm -23 <(echo "$from_files") <(echo "$to_files"))

  # Find files only in target
  local only_in_to
  only_in_to=$(comm -13 <(echo "$from_files") <(echo "$to_files"))

  # Find common files that differ
  local common_files differ_files=""
  common_files=$(comm -12 <(echo "$from_files") <(echo "$to_files"))
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if ! diff -q "$from_path/$file" "$to_path/$file" &>/dev/null; then
      differ_files="${differ_files}${file}"$'\n'
    fi
  done <<< "$common_files"
  differ_files="${differ_files%$'\n'}"

  # Check if there are any differences
  if [[ -z "$only_in_from" ]] && [[ -z "$only_in_to" ]] && [[ -z "$differ_files" ]]; then
    if [[ "$quiet" != "true" ]]; then
      _mt_info "✓ Packages are identical"
    fi
    return 0
  fi

  if [[ "$quiet" == "true" ]]; then
    return 1
  fi

  # Output differences
  if [[ -n "$only_in_from" ]]; then
    echo "Only in $from_module/$package_name:"
    echo "$only_in_from" | while read -r file; do
      echo "  $file"
    done
    echo ""
  fi

  if [[ -n "$only_in_to" ]]; then
    echo "Only in $to_module/$package_name:"
    echo "$only_in_to" | while read -r file; do
      echo "  $file"
    done
    echo ""
  fi

  if [[ -n "$differ_files" ]]; then
    echo "Files that differ:"
    echo "$differ_files" | while read -r file; do
      echo "  $file"
    done
    echo ""
  fi

  # Show content diff if requested
  if [[ "$show_content" == "true" ]] && [[ -n "$differ_files" ]]; then
    echo "--- Content differences ---"
    echo "$differ_files" | while read -r file; do
      [[ -z "$file" ]] && continue
      echo ""
      echo "=== $file ==="
      diff -u "$from_path/$file" "$to_path/$file" 2>/dev/null | \
        sed -e "s|$from_path|$from_module/$package_name|g" \
            -e "s|$to_path|$to_module/$package_name|g" || true
    done
  fi

  return 1
}
