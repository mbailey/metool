#!/usr/bin/env bash
# working-set.sh - Helper functions for working set management (MT-11)

# ==============================================================================
# Module Helper Functions
# ==============================================================================

# Get module path from name (follows symlink)
# Returns: Absolute path to module directory or empty if not found
_mt_module_path() {
  local module_name="${1:?module name required}"
  local link="${MT_MODULES_DIR}/${module_name}"

  if [[ ! -L "$link" ]]; then
    return 1
  fi

  readlink -f "$link" 2>/dev/null
}

# Check if module is in working set
# Returns: 0 if module exists in working set, 1 otherwise
_mt_module_in_working_set() {
  local module_name="${1:?module name required}"
  [[ -L "${MT_MODULES_DIR}/${module_name}" ]]
}

# Get module name from path
# Returns: Module name (basename of path)
_mt_module_name_from_path() {
  local module_path="${1:?module path required}"
  basename "$module_path"
}

# ==============================================================================
# Package Helper Functions
# ==============================================================================

# Get package path from name (follows symlink)
# Returns: Absolute path to package directory or empty if not found
_mt_package_path() {
  local package_name="${1:?package name required}"
  local link="${MT_PACKAGES_DIR}/${package_name}"

  if [[ ! -L "$link" ]]; then
    return 1
  fi

  readlink -f "$link" 2>/dev/null
}

# Check if package is in working set
# Returns: 0 if package exists in working set, 1 otherwise
_mt_package_in_working_set() {
  local package_name="${1:?package name required}"
  [[ -L "${MT_PACKAGES_DIR}/${package_name}" ]]
}

# Check if package is installed (has active stow symlinks)
# Returns: 0 if package is installed, 1 otherwise
_mt_package_is_installed() {
  local package_name="${1:?package name required}"

  local package_path
  package_path=$(_mt_package_path "$package_name") || return 1

  # Check each stow component directory for symlinks pointing to this package
  for component_dir in bin shell config; do
    local stow_dir="${MT_PKG_DIR}/${component_dir}"
    [[ -d "$stow_dir" ]] || continue

    # Look for any symlinks that point into this package
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue

      local link_target
      link_target=$(readlink -f "$link" 2>/dev/null) || continue

      # Check if symlink points into this package directory
      if [[ "$link_target" == "$package_path"/* ]]; then
        return 0
      fi
    done < <(find "$stow_dir" -type l 2>/dev/null)
  done

  return 1
}

# Get module name for package
# Returns: Module name that package belongs to
_mt_package_module_name() {
  local package_name="${1:?package name required}"

  local package_path
  package_path=$(_mt_package_path "$package_name") || return 1

  # Extract module name from path
  # Expected format: .../.metool/modules/<module>/<package>
  if [[ "$package_path" =~ /modules/([^/]+)/.+$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

# ==============================================================================
# Service Detection Functions
# ==============================================================================

# Check if package has service files
# Returns: 0 if package has systemd/launchd service files, 1 otherwise
_mt_package_has_services() {
  local package_name="${1:?package name required}"

  local package_path
  package_path=$(_mt_package_path "$package_name") || return 1

  # Check for systemd user units (Linux)
  local systemd_dir="${package_path}/config/dot-config/systemd/user"
  if [[ -d "$systemd_dir" ]] && [[ -n "$(find "$systemd_dir" -name "*.service" -type f 2>/dev/null)" ]]; then
    return 0
  fi

  # Check for LaunchAgents (macOS)
  local launchd_dir="${package_path}/config/macos"
  if [[ -d "$launchd_dir" ]] && [[ -n "$(find "$launchd_dir" -name "*.plist" -type f 2>/dev/null)" ]]; then
    return 0
  fi

  return 1
}
