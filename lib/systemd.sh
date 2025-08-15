#!/usr/bin/env bash
# systemd.sh - Functions for managing systemd services in metool packages

# Enable systemd service(s) from a metool package
_mt_enable() {
  local package="$1"
  local service="$2"
  local now_flag=""
  
  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --now)
        now_flag="--now"
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage: mt enable PACKAGE[/SERVICE] [--now]

Enable systemd user service(s) from a metool package.

Arguments:
  PACKAGE         The metool package containing the service(s)
  SERVICE         Optional specific service name (enables all if omitted)
  --now           Also start the service immediately

Examples:
  mt enable work/backup-service
  mt enable work/backup-service/backup.service
  mt enable personal/vpn --now
EOF
        return 0
        ;;
      *)
        shift
        ;;
    esac
  done
  
  if [[ -z "$package" ]]; then
    _mt_error "Usage: mt enable PACKAGE[/SERVICE] [--now]"
    return 1
  fi
  
  # Extract service name if provided as package/service
  if [[ "$package" == */* ]] && [[ "$service" == "" ]]; then
    service="${package##*/}"
    package="${package%/*}"
  fi
  
  # Find the package directory
  local pkg_dir=$(_mt_find_package "$package")
  if [[ -z "$pkg_dir" ]]; then
    _mt_error "Package not found: $package"
    return 1
  fi
  
  # Ensure package is installed first
  _mt_log DEBUG "Ensuring package is installed: $package"
  _mt_stow "$package" || return 1
  
  # Find systemd service files
  local service_dir="$pkg_dir/config/dot-config/systemd/user"
  if [[ ! -d "$service_dir" ]]; then
    _mt_error "No systemd services found in package: $package"
    return 1
  fi
  
  # Enable specific service or all services
  local enabled_count=0
  if [[ -n "$service" ]]; then
    # Enable specific service
    if [[ ! -f "$service_dir/$service" ]]; then
      # Try with .service extension if not provided
      if [[ "$service" != *.service ]] && [[ -f "$service_dir/$service.service" ]]; then
        service="$service.service"
      else
        _mt_error "Service not found: $service in package $package"
        return 1
      fi
    fi
    
    echo "Enabling $service from $package..."
    systemctl --user enable $now_flag "$service" && ((enabled_count++))
  else
    # Enable all services in package
    for service_file in "$service_dir"/*.service; do
      [[ -f "$service_file" ]] || continue
      local service_name=$(basename "$service_file")
      echo "Enabling $service_name from $package..."
      systemctl --user enable $now_flag "$service_name" && ((enabled_count++))
    done
  fi
  
  if [[ $enabled_count -eq 0 ]]; then
    _mt_error "No services were enabled"
    return 1
  fi
  
  # Reload systemd to pick up any changes
  systemctl --user daemon-reload
  
  echo "✓ Enabled $enabled_count service(s) from $package"
  return 0
}

# Disable systemd service(s) from a metool package
_mt_disable() {
  local package="$1"
  local service="$2"
  local now_flag=""
  
  # Parse flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --now)
        now_flag="--now"
        shift
        ;;
      -h|--help)
        cat <<EOF
Usage: mt disable PACKAGE[/SERVICE] [--now]

Disable systemd user service(s) from a metool package while preserving the service file.

Arguments:
  PACKAGE         The metool package containing the service(s)
  SERVICE         Optional specific service name (disables all if omitted)
  --now           Also stop the service immediately

Examples:
  mt disable work/backup-service
  mt disable work/backup-service/backup.service
  mt disable personal/vpn --now

Note: Unlike 'systemctl disable', this preserves the service file symlink.
EOF
        return 0
        ;;
      *)
        shift
        ;;
    esac
  done
  
  if [[ -z "$package" ]]; then
    _mt_error "Usage: mt disable PACKAGE[/SERVICE] [--now]"
    return 1
  fi
  
  # Extract service name if provided as package/service
  if [[ "$package" == */* ]] && [[ "$service" == "" ]]; then
    service="${package##*/}"
    package="${package%/*}"
  fi
  
  # Find the package directory
  local pkg_dir=$(_mt_find_package "$package")
  if [[ -z "$pkg_dir" ]]; then
    _mt_error "Package not found: $package"
    return 1
  fi
  
  # Find systemd service files
  local service_dir="$pkg_dir/config/dot-config/systemd/user"
  if [[ ! -d "$service_dir" ]]; then
    _mt_error "No systemd services found in package: $package"
    return 1
  fi
  
  # Disable specific service or all services
  local disabled_count=0
  if [[ -n "$service" ]]; then
    # Disable specific service
    if [[ ! -f "$service_dir/$service" ]]; then
      # Try with .service extension if not provided
      if [[ "$service" != *.service ]] && [[ -f "$service_dir/$service.service" ]]; then
        service="$service.service"
      else
        _mt_error "Service not found: $service in package $package"
        return 1
      fi
    fi
    
    echo "Disabling $service from $package..."
    systemctl --user disable $now_flag "$service" && ((disabled_count++))
  else
    # Disable all services in package
    for service_file in "$service_dir"/*.service; do
      [[ -f "$service_file" ]] || continue
      local service_name=$(basename "$service_file")
      echo "Disabling $service_name from $package..."
      systemctl --user disable $now_flag "$service_name" && ((disabled_count++))
    done
  fi
  
  if [[ $disabled_count -eq 0 ]]; then
    _mt_error "No services were disabled"
    return 1
  fi
  
  # Restore the service file symlinks that systemd removed
  echo "Restoring service file symlinks..."
  _mt_stow "$package" || _mt_warn "Failed to restore some symlinks"
  
  # Reload systemd to pick up any changes
  systemctl --user daemon-reload
  
  echo "✓ Disabled $disabled_count service(s) from $package (service files preserved)"
  return 0
}

# Helper function to find a package directory
_mt_find_package() {
  local package="$1"
  
  # If package contains /, treat as module/package
  if [[ "$package" == */* ]]; then
    local module="${package%%/*}"
    local pkg_name="${package#*/}"
    
    # Check if it's a valid module directory
    if [[ -d "$MT_ROOT/$module/$pkg_name" ]]; then
      echo "$MT_ROOT/$module/$pkg_name"
      return 0
    fi
  else
    # Search all modules for the package
    for module_dir in "$MT_ROOT"/*; do
      [[ -d "$module_dir" ]] || continue
      [[ "$(basename "$module_dir")" == ".*" ]] && continue
      
      if [[ -d "$module_dir/$package" ]]; then
        echo "$module_dir/$package"
        return 0
      fi
    done
  fi
  
  return 1
}