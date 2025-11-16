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

  # Build index of installed packages for performance
  # (avoid calling find 3x per package)
  local -A installed_packages
  for component_dir in bin shell config; do
    local stow_dir="${MT_PKG_DIR}/${component_dir}"
    [[ -d "$stow_dir" ]] || continue

    while IFS= read -r link; do
      [[ -L "$link" ]] || continue
      local link_target
      link_target=$(readlink -f "$link" 2>/dev/null) || continue

      # Extract package name from symlink target path
      # Expected format: .../.metool/modules/<module>/<package>/...
      if [[ "$link_target" =~ /modules/[^/]+/([^/]+)/ ]]; then
        installed_packages["${BASH_REMATCH[1]}"]=1
      fi
    done < <(find "$stow_dir" -type l 2>/dev/null)
  done

  # Check if any packages exist
  local package_count=0
  local -a packages=()

  while IFS= read -r package_link; do
    [[ -L "$package_link" ]] || continue
    local package_name=$(basename "$package_link")
    local target=$(readlink -f "$package_link" 2>/dev/null)
    local status="○"  # Not installed
    local broken=false

    # Check if symlink is broken
    if [[ -z "$target" ]] || [[ ! -d "$target" ]]; then
      status="✗"
      broken=true
      target="${target:-broken}"
    else
      # Check if package is installed using pre-built index
      if [[ -n "${installed_packages[$package_name]}" ]]; then
        status="●"  # Installed
      fi
    fi

    # Extract module name from target path
    local module_name=""
    if [[ "$broken" == "false" ]]; then
      if [[ "$target" =~ /modules/([^/]+)/.+$ ]]; then
        module_name="${BASH_REMATCH[1]}"
      fi
    fi

    packages+=("${status}\t${package_name}\t${module_name}\t${target}")
    ((package_count++))
  done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null | sort)

  if [[ $package_count -eq 0 ]]; then
    _mt_info "No packages in working set"
    _mt_info "Add packages with: mt package add <module>/<package>"
    return 0
  fi

  # Output header
  printf "%-3s %-25s %-20s %s\n" "" "PACKAGE" "MODULE" "PATH"
  printf "%-3s %-25s %-20s %s\n" "---" "-------" "------" "----"

  # Output packages
  for package_info in "${packages[@]}"; do
    echo -e "$package_info"
  done | column -t -s $'\t'

  echo
  echo "Legend: ● installed, ○ not installed, ✗ broken"
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

# Install package from working set
_mt_package_install() {
  local package_name="$1"
  shift || true

  # Validate input
  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package install <package> [options]"
    _mt_info "Options:"
    _mt_info "  --no-bin      Skip installing bin/ directory"
    _mt_info "  --no-config   Skip installing config/ directory"
    _mt_info "  --no-shell    Skip installing shell/ directory"
    return 1
  fi

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

  # Parse exclusion options
  local skip_bin=false
  local skip_config=false
  local skip_shell=false

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
      *)
        _mt_error "Unknown option: $1"
        return 1
        ;;
    esac
  done

  # Build stow options based on exclusions
  local -a stow_opts=()

  if $skip_bin || $skip_config || $skip_shell; then
    # With exclusions, we need to handle each component separately
    _mt_info "Installing package with exclusions: $package_name"

    local installed_components=()
    local skipped_components=()

    # Install bin/ unless skipped
    if ! $skip_bin && [[ -d "$package_path/bin" ]]; then
      if command stow --dir="$package_path" --target="${MT_PKG_DIR}/bin" bin 2>&1; then
        installed_components+=("bin")
      else
        _mt_error "Failed to install bin component"
        return 1
      fi
    elif $skip_bin && [[ -d "$package_path/bin" ]]; then
      skipped_components+=("bin")
    fi

    # Install config/ unless skipped
    if ! $skip_config && [[ -d "$package_path/config" ]]; then
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
    elif $skip_config && [[ -d "$package_path/config" ]]; then
      skipped_components+=("config")
    fi

    # Install shell/ unless skipped
    if ! $skip_shell && [[ -d "$package_path/shell" ]]; then
      mkdir -p "${MT_PKG_DIR}/shell/${package_name}"
      if command stow --dir="$package_path" --target="${MT_PKG_DIR}/shell/${package_name}" shell 2>&1; then
        installed_components+=("shell")
      else
        _mt_error "Failed to install shell component"
        return 1
      fi
    elif $skip_shell && [[ -d "$package_path/shell" ]]; then
      skipped_components+=("shell")
    fi

    if [[ ${#installed_components[@]} -gt 0 ]]; then
      _mt_info "✓ Installed: ${installed_components[*]}"
    fi
    if [[ ${#skipped_components[@]} -gt 0 ]]; then
      _mt_info "Skipped: ${skipped_components[*]}"
    fi

  else
    # No exclusions - use standard stow function
    _mt_info "Installing package: $package_name"
    _mt_stow "$package_path"
  fi

  _mt_info "✓ Package installed: $package_name"

  # Check if package has services
  if _mt_package_has_services "$package_name"; then
    _mt_info "This package includes system services"
    _mt_info "Manage with: mt package service $package_name <start|stop|status|enable|disable>"
  fi

  return 0
}

# Uninstall package (remove stow symlinks)
_mt_package_uninstall() {
  local package_name="$1"
  shift || true

  # Validate input
  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package uninstall <package> [options]"
    _mt_info "Options:"
    _mt_info "  --no-bin      Skip uninstalling bin/ directory"
    _mt_info "  --no-config   Skip uninstalling config/ directory"
    _mt_info "  --no-shell    Skip uninstalling shell/ directory"
    return 1
  fi

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

  # Parse exclusion options
  local skip_bin=false
  local skip_config=false
  local skip_shell=false

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
      *)
        _mt_error "Unknown option: $1"
        return 1
        ;;
    esac
  done

  _mt_info "Uninstalling package: $package_name"

  local uninstalled_components=()
  local skipped_components=()

  # Uninstall bin/ unless skipped
  if ! $skip_bin && [[ -d "$package_path/bin" ]]; then
    if command stow -D --dir="$package_path" --target="${MT_PKG_DIR}/bin" bin 2>&1; then
      uninstalled_components+=("bin")
    else
      _mt_warning "Failed to uninstall bin component (may not have been installed)"
    fi
  elif $skip_bin && [[ -d "$package_path/bin" ]]; then
    skipped_components+=("bin")
  fi

  # Uninstall config/ unless skipped
  if ! $skip_config && [[ -d "$package_path/config" ]]; then
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
  elif $skip_config && [[ -d "$package_path/config" ]]; then
    skipped_components+=("config")
  fi

  # Uninstall shell/ unless skipped
  if ! $skip_shell && [[ -d "$package_path/shell" ]]; then
    if command stow -D --dir="$package_path" --target="${MT_PKG_DIR}/shell/${package_name}" shell 2>&1; then
      uninstalled_components+=("shell")
      # Clean up empty metool shell directory
      rmdir "${MT_PKG_DIR}/shell/${package_name}" 2>/dev/null || true
    else
      _mt_warning "Failed to uninstall shell component"
    fi
  elif $skip_shell && [[ -d "$package_path/shell" ]]; then
    skipped_components+=("shell")
  fi

  if [[ ${#uninstalled_components[@]} -gt 0 ]]; then
    _mt_info "✓ Uninstalled: ${uninstalled_components[*]}"
  fi
  if [[ ${#skipped_components[@]} -gt 0 ]]; then
    _mt_info "Skipped: ${skipped_components[*]}"
  fi

  _mt_info "✓ Package uninstalled: $package_name"
  return 0
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
    -h|--help|"")
      cat <<EOF
Usage: mt package <command> [options]

Manage metool packages in working set.

Commands:
  list                       List packages in working set
  add <mod>/<pkg>            Add package to working set
  remove <package>           Remove package from working set
  edit <package>             Open package in editor
  install <package> [opts]   Install package using stow
  uninstall <package> [opts] Uninstall package (remove symlinks)
  service <cmd> <package>    Manage package services (systemd/launchd)
  new NAME [PATH]            Create a new package from template

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
  mt package install vim-config --no-bin --no-shell
  mt package service start prometheus
  mt package service logs prometheus -f
  mt package uninstall git-tools
  mt package remove git-tools
  mt package edit git-tools

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
