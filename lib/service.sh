#!/usr/bin/env bash
# service.sh - Service management commands (MT-11)

# Detect operating system
_mt_service_detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "unsupported"
  fi
}

# Check if running as root
_mt_service_is_root() {
  [[ $EUID -eq 0 ]]
}

# Get service files for package
# Returns list of service files with format: type:path
_mt_service_get_files() {
  local package_name="${1:?package name required}"

  local package_path
  package_path=$(_mt_package_path "$package_name") || return 1

  local os=$(_mt_service_detect_os)
  local -a service_files=()

  case "$os" in
    linux)
      # Check for systemd user units
      local systemd_user_dir="${package_path}/config/dot-config/systemd/user"
      if [[ -d "$systemd_user_dir" ]]; then
        while IFS= read -r file; do
          service_files+=("systemd-user:$file")
        done < <(find "$systemd_user_dir" -name "*.service" -type f 2>/dev/null)
      fi

      # Check for systemd system units
      local systemd_system_dir="${package_path}/config/etc/systemd/system"
      if [[ -d "$systemd_system_dir" ]]; then
        while IFS= read -r file; do
          service_files+=("systemd-system:$file")
        done < <(find "$systemd_system_dir" -name "*.service" -type f 2>/dev/null)
      fi
      ;;

    macos)
      # Check for LaunchAgents
      local launchd_dir="${package_path}/config/macos"
      if [[ -d "$launchd_dir" ]]; then
        while IFS= read -r file; do
          service_files+=("launchd:$file")
        done < <(find "$launchd_dir" -name "*.plist" -type f 2>/dev/null)
      fi
      ;;
  esac

  if [[ ${#service_files[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${service_files[@]}"
  return 0
}

# List services for a package
_mt_service_list() {
  local package_name="$1"

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service list <package>"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_info "No service files found in package: $package_name"
    return 0
  fi

  _mt_info "Service files in $package_name:"
  for service_file in "${service_files[@]}"; do
    local type="${service_file%%:*}"
    local path="${service_file#*:}"
    local name=$(basename "$path")

    echo "  [$type] $name"
  done
}

# Start service
_mt_service_start() {
  local package_name="$1"
  local service_name="${2:-}"

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service start <package> [service-name]"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  # Check if package is installed
  if ! _mt_package_is_installed "$package_name"; then
    _mt_error "Package is not installed: $package_name"
    _mt_info "Install first: mt package install $package_name"
    return 1
  fi

  local os=$(_mt_service_detect_os)
  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_error "No service files found in package: $package_name"
    return 1
  fi

  # If specific service name provided, find it
  if [[ -n "$service_name" ]]; then
    local found=false
    for service_file in "${service_files[@]}"; do
      local path="${service_file#*:}"
      if [[ "$(basename "$path")" == "$service_name" ]]; then
        service_files=("$service_file")
        found=true
        break
      fi
    done

    if ! $found; then
      _mt_error "Service not found: $service_name"
      return 1
    fi
  fi

  # Start each service
  for service_file in "${service_files[@]}"; do
    local type="${service_file%%:*}"
    local path="${service_file#*:}"
    local name=$(basename "$path" .service)
    local unit_name=$(basename "$path")

    _mt_info "Starting service: $name"

    case "$type" in
      systemd-user)
        systemctl --user start "$unit_name"
        ;;
      systemd-system)
        if ! _mt_service_is_root; then
          sudo systemctl start "$unit_name"
        else
          systemctl start "$unit_name"
        fi
        ;;
      launchd)
        launchctl start "$(basename "$path" .plist)"
        ;;
    esac

    if [[ $? -eq 0 ]]; then
      _mt_info "✓ Service started: $name"
    else
      _mt_error "Failed to start service: $name"
      return 1
    fi
  done

  return 0
}

# Stop service
_mt_service_stop() {
  local package_name="$1"
  local service_name="${2:-}"

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service stop <package> [service-name]"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  local os=$(_mt_service_detect_os)
  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_error "No service files found in package: $package_name"
    return 1
  fi

  # If specific service name provided, find it
  if [[ -n "$service_name" ]]; then
    local found=false
    for service_file in "${service_files[@]}"; do
      local path="${service_file#*:}"
      if [[ "$(basename "$path")" == "$service_name" ]]; then
        service_files=("$service_file")
        found=true
        break
      fi
    done

    if ! $found; then
      _mt_error "Service not found: $service_name"
      return 1
    fi
  fi

  # Stop each service
  for service_file in "${service_files[@]}"; do
    local type="${service_file%%:*}"
    local path="${service_file#*:}"
    local name=$(basename "$path" .service)
    local unit_name=$(basename "$path")

    _mt_info "Stopping service: $name"

    case "$type" in
      systemd-user)
        systemctl --user stop "$unit_name"
        ;;
      systemd-system)
        if ! _mt_service_is_root; then
          sudo systemctl stop "$unit_name"
        else
          systemctl stop "$unit_name"
        fi
        ;;
      launchd)
        launchctl stop "$(basename "$path" .plist)"
        ;;
    esac

    if [[ $? -eq 0 ]]; then
      _mt_info "✓ Service stopped: $name"
    else
      _mt_error "Failed to stop service: $name"
      return 1
    fi
  done

  return 0
}

# Restart service
_mt_service_restart() {
  local package_name="$1"
  local service_name="${2:-}"

  _mt_info "Restarting service(s) in package: $package_name"
  _mt_service_stop "$package_name" "$service_name" || return 1
  sleep 1
  _mt_service_start "$package_name" "$service_name" || return 1
  return 0
}

# Show service status
_mt_service_status() {
  local package_name="$1"
  local service_name="${2:-}"

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service status <package> [service-name]"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  local os=$(_mt_service_detect_os)
  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_error "No service files found in package: $package_name"
    return 1
  fi

  # If specific service name provided, find it
  if [[ -n "$service_name" ]]; then
    local found=false
    for service_file in "${service_files[@]}"; do
      local path="${service_file#*:}"
      if [[ "$(basename "$path")" == "$service_name" ]]; then
        service_files=("$service_file")
        found=true
        break
      fi
    done

    if ! $found; then
      _mt_error "Service not found: $service_name"
      return 1
    fi
  fi

  # Show status for each service
  for service_file in "${service_files[@]}"; do
    local type="${service_file%%:*}"
    local path="${service_file#*:}"
    local name=$(basename "$path" .service)
    local unit_name=$(basename "$path")

    echo "Service: $name [$type]"

    case "$type" in
      systemd-user)
        systemctl --user status "$unit_name"
        ;;
      systemd-system)
        if ! _mt_service_is_root; then
          sudo systemctl status "$unit_name"
        else
          systemctl status "$unit_name"
        fi
        ;;
      launchd)
        launchctl list | grep "$(basename "$path" .plist)" || echo "Not running"
        ;;
    esac

    echo ""
  done

  return 0
}

# Enable service (start on boot/login)
_mt_service_enable() {
  local package_name="$1"
  local service_name="${2:-}"

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service enable <package> [service-name]"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  # Check if package is installed
  if ! _mt_package_is_installed "$package_name"; then
    _mt_error "Package is not installed: $package_name"
    _mt_info "Install first: mt package install $package_name"
    return 1
  fi

  local os=$(_mt_service_detect_os)
  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_error "No service files found in package: $package_name"
    return 1
  fi

  # If specific service name provided, find it
  if [[ -n "$service_name" ]]; then
    local found=false
    for service_file in "${service_files[@]}"; do
      local path="${service_file#*:}"
      if [[ "$(basename "$path")" == "$service_name" ]]; then
        service_files=("$service_file")
        found=true
        break
      fi
    done

    if ! $found; then
      _mt_error "Service not found: $service_name"
      return 1
    fi
  fi

  # Enable each service
  for service_file in "${service_files[@]}"; do
    local type="${service_file%%:*}"
    local path="${service_file#*:}"
    local name=$(basename "$path" .service)
    local unit_name=$(basename "$path")

    _mt_info "Enabling service: $name"

    case "$type" in
      systemd-user)
        systemctl --user enable "$unit_name"
        ;;
      systemd-system)
        if ! _mt_service_is_root; then
          sudo systemctl enable "$unit_name"
        else
          systemctl enable "$unit_name"
        fi
        ;;
      launchd)
        local target_path="${HOME}/Library/LaunchAgents/$(basename "$path")"
        if [[ ! -L "$target_path" ]] && [[ ! -f "$target_path" ]]; then
          mkdir -p "${HOME}/Library/LaunchAgents"
          ln -s "$path" "$target_path"
        fi
        launchctl load "$target_path"
        ;;
    esac

    if [[ $? -eq 0 ]]; then
      _mt_info "✓ Service enabled: $name"
    else
      _mt_error "Failed to enable service: $name"
      return 1
    fi
  done

  return 0
}

# Disable service (don't start on boot/login)
_mt_service_disable() {
  local package_name="$1"
  local service_name="${2:-}"

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service disable <package> [service-name]"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  local os=$(_mt_service_detect_os)
  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_error "No service files found in package: $package_name"
    return 1
  fi

  # If specific service name provided, find it
  if [[ -n "$service_name" ]]; then
    local found=false
    for service_file in "${service_files[@]}"; do
      local path="${service_file#*:}"
      if [[ "$(basename "$path")" == "$service_name" ]]; then
        service_files=("$service_file")
        found=true
        break
      fi
    done

    if ! $found; then
      _mt_error "Service not found: $service_name"
      return 1
    fi
  fi

  # Disable each service
  for service_file in "${service_files[@]}"; do
    local type="${service_file%%:*}"
    local path="${service_file#*:}"
    local name=$(basename "$path" .service)
    local unit_name=$(basename "$path")

    _mt_info "Disabling service: $name"

    case "$type" in
      systemd-user)
        systemctl --user disable "$unit_name"
        ;;
      systemd-system)
        if ! _mt_service_is_root; then
          sudo systemctl disable "$unit_name"
        else
          systemctl disable "$unit_name"
        fi
        ;;
      launchd)
        local target_path="${HOME}/Library/LaunchAgents/$(basename "$path")"
        if [[ -f "$target_path" ]] || [[ -L "$target_path" ]]; then
          launchctl unload "$target_path"
          rm -f "$target_path"
        fi
        ;;
    esac

    if [[ $? -eq 0 ]]; then
      _mt_info "✓ Service disabled: $name"
    else
      _mt_error "Failed to disable service: $name"
      return 1
    fi
  done

  return 0
}

# View service logs
_mt_service_logs() {
  local package_name="$1"
  local service_name="${2:-}"
  shift 2 2>/dev/null || shift 1

  # Parse options
  local follow=false
  local lines=50

  while [[ $# -gt 0 ]]; do
    case $1 in
      -f|--follow)
        follow=true
        shift
        ;;
      -n|--lines)
        lines="$2"
        shift 2
        ;;
      *)
        _mt_error "Unknown option: $1"
        return 1
        ;;
    esac
  done

  if [[ -z "$package_name" ]]; then
    _mt_error "Usage: mt package service logs <package> [service-name] [-f] [-n NUM]"
    return 1
  fi

  if ! _mt_package_in_working_set "$package_name"; then
    _mt_error "Package not found in working set: $package_name"
    return 1
  fi

  local os=$(_mt_service_detect_os)
  local -a service_files
  mapfile -t service_files < <(_mt_service_get_files "$package_name" 2>/dev/null)

  if [[ ${#service_files[@]} -eq 0 ]]; then
    _mt_error "No service files found in package: $package_name"
    return 1
  fi

  # If specific service name provided, find it
  if [[ -n "$service_name" ]]; then
    local found=false
    for service_file in "${service_files[@]}"; do
      local path="${service_file#*:}"
      if [[ "$(basename "$path")" == "$service_name" ]]; then
        service_files=("$service_file")
        found=true
        break
      fi
    done

    if ! $found; then
      _mt_error "Service not found: $service_name"
      return 1
    fi
  fi

  # Show logs for first service (or specified service)
  local service_file="${service_files[0]}"
  local type="${service_file%%:*}"
  local path="${service_file#*:}"
  local name=$(basename "$path" .service)
  local unit_name=$(basename "$path")

  case "$type" in
    systemd-user)
      local -a journal_opts=("--user" "-u" "$unit_name" "-n" "$lines")
      if $follow; then
        journal_opts+=("-f")
      fi
      journalctl "${journal_opts[@]}"
      ;;
    systemd-system)
      local -a journal_opts=("-u" "$unit_name" "-n" "$lines")
      if $follow; then
        journal_opts+=("-f")
      fi
      if ! _mt_service_is_root; then
        sudo journalctl "${journal_opts[@]}"
      else
        journalctl "${journal_opts[@]}"
      fi
      ;;
    macos)
      _mt_info "macOS service logs - checking stdout/stderr files"
      # Try to find log files
      local stdout_log="/tmp/${name}.out"
      local stderr_log="/tmp/${name}.err"

      if [[ -f "$stdout_log" ]]; then
        echo "=== Standard Output ==="
        if $follow; then
          tail -n "$lines" -f "$stdout_log"
        else
          tail -n "$lines" "$stdout_log"
        fi
      fi

      if [[ -f "$stderr_log" ]]; then
        echo "=== Standard Error ==="
        if $follow; then
          tail -n "$lines" -f "$stderr_log"
        else
          tail -n "$lines" "$stderr_log"
        fi
      fi

      if [[ ! -f "$stdout_log" ]] && [[ ! -f "$stderr_log" ]]; then
        _mt_info "No log files found. Check Console.app or system logs."
      fi
      ;;
  esac

  return 0
}

# Main service command dispatcher
_mt_service() {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
    list)
      _mt_service_list "$@"
      ;;
    start)
      _mt_service_start "$@"
      ;;
    stop)
      _mt_service_stop "$@"
      ;;
    restart)
      _mt_service_restart "$@"
      ;;
    status)
      _mt_service_status "$@"
      ;;
    enable)
      _mt_service_enable "$@"
      ;;
    disable)
      _mt_service_disable "$@"
      ;;
    logs)
      _mt_service_logs "$@"
      ;;
    -h|--help|"")
      cat <<EOF
Usage: mt package service <command> <package> [service-name] [options]

Manage services in metool packages.

Commands:
  list <package>              List service files in package
  start <package> [service]   Start service(s)
  stop <package> [service]    Stop service(s)
  restart <package> [service] Restart service(s)
  status <package> [service]  Show service status
  enable <package> [service]  Enable service at boot/login
  disable <package> [service] Disable service at boot/login
  logs <package> [service]    View service logs

Log Options:
  -f, --follow        Follow log output
  -n, --lines NUM     Show NUM lines (default: 50)

Examples:
  mt package service list prometheus
  mt package service start prometheus
  mt package service status prometheus prometheus.service
  mt package service logs prometheus -f
  mt package service enable prometheus

Note: Services are managed via systemd (Linux) or launchd (macOS)

EOF
      return 0
      ;;
    *)
      _mt_error "Unknown service command: $subcommand"
      _mt_info "Run 'mt package service --help' for usage"
      return 1
      ;;
  esac
}
