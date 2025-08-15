#!/usr/bin/env bash
# Shared functions for service management

# Exit on error unless explicitly handled
set -o nounset -o pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[${SERVICE_NAME:-service}]${NC} $*"
}

log_error() {
    echo -e "${RED}[${SERVICE_NAME:-service}]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[${SERVICE_NAME:-service}]${NC} $*"
}

log_info() {
    echo -e "${BLUE}[${SERVICE_NAME:-service}]${NC} $*"
}

log_debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo -e "${YELLOW}[DEBUG]${NC} $*"
}

log_verbose() {
    [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${BLUE}[VERBOSE]${NC} $*"
}

# OS detection
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unsupported"
    fi
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if systemd is available
has_systemd() {
    command_exists systemctl && [[ -d /sys/fs/cgroup/systemd ]]
}

# Check if launchd is available (macOS)
has_launchd() {
    command_exists launchctl && [[ -d /System/Library/LaunchDaemons ]]
}

# Service status helpers
service_is_active() {
    local service="$1"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            if ! has_systemd; then
                log_error "systemd is not available"
                return 1
            fi
            
            if is_root; then
                systemctl is-active "$service" &>/dev/null
            else
                systemctl --user is-active "$service" &>/dev/null
            fi
            ;;
        macos)
            if ! has_launchd; then
                log_error "launchd is not available"
                return 1
            fi
            
            local label="com.${SERVICE_NAME}"
            launchctl list | grep -q "$label"
            ;;
        *)
            log_error "Unsupported operating system: $os"
            return 1
            ;;
    esac
}

service_is_enabled() {
    local service="$1"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            if is_root; then
                systemctl is-enabled "$service" &>/dev/null
            else
                systemctl --user is-enabled "$service" &>/dev/null
            fi
            ;;
        macos)
            # On macOS, services in LaunchAgents are enabled by default
            local plist_path="$HOME/Library/LaunchAgents/com.${SERVICE_NAME}.plist"
            [[ -f "$plist_path" ]]
            ;;
    esac
}

# Get service PID
get_service_pid() {
    local service="$1"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            local pid
            if is_root; then
                pid=$(systemctl show "$service" --property MainPID --value 2>/dev/null)
            else
                pid=$(systemctl --user show "$service" --property MainPID --value 2>/dev/null)
            fi
            
            # Return PID only if it's a valid number and not 0
            if [[ "$pid" =~ ^[0-9]+$ ]] && [[ "$pid" -ne 0 ]]; then
                echo "$pid"
            fi
            ;;
        macos)
            local label="com.${SERVICE_NAME}"
            local pid=$(launchctl list | grep "$label" | awk '{print $1}' | grep -v "^-$")
            if [[ "$pid" =~ ^[0-9]+$ ]]; then
                echo "$pid"
            fi
            ;;
    esac
}

# Get service status with color coding
get_service_status() {
    local service="$1"
    
    if service_is_active "$service"; then
        echo -e "${GREEN}●${NC} Active"
    else
        echo -e "${RED}●${NC} Inactive"
    fi
}

# Check if service unit file exists
service_unit_exists() {
    local service="$1"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            if is_root; then
                systemctl cat "$service" &>/dev/null
            else
                systemctl --user cat "$service" &>/dev/null
            fi
            ;;
        macos)
            local plist_path="$HOME/Library/LaunchAgents/com.${SERVICE_NAME}.plist"
            [[ -f "$plist_path" ]]
            ;;
    esac
}

# Standard service operations
start_service() {
    local service="$1"
    local os=$(detect_os)
    
    log_verbose "Starting service: $service"
    
    case "$os" in
        linux)
            if is_root; then
                systemctl start "$service"
            else
                systemctl --user start "$service"
            fi
            ;;
        macos)
            local label="com.${SERVICE_NAME}"
            launchctl start "$label"
            ;;
    esac
}

stop_service() {
    local service="$1"
    local os=$(detect_os)
    
    log_verbose "Stopping service: $service"
    
    case "$os" in
        linux)
            if is_root; then
                systemctl stop "$service"
            else
                systemctl --user stop "$service"
            fi
            ;;
        macos)
            local label="com.${SERVICE_NAME}"
            launchctl stop "$label"
            ;;
    esac
}

enable_service() {
    local service="$1"
    local os=$(detect_os)
    
    log_verbose "Enabling service: $service"
    
    case "$os" in
        linux)
            if is_root; then
                systemctl enable "$service"
            else
                systemctl --user enable "$service"
            fi
            ;;
        macos)
            local plist_path="$HOME/Library/LaunchAgents/com.${SERVICE_NAME}.plist"
            if [[ -f "$plist_path" ]]; then
                launchctl load -w "$plist_path"
            else
                log_error "LaunchAgent plist not found: $plist_path"
                return 1
            fi
            ;;
    esac
}

disable_service() {
    local service="$1"
    local os=$(detect_os)
    
    log_verbose "Disabling service: $service"
    
    case "$os" in
        linux)
            if is_root; then
                systemctl disable "$service"
            else
                systemctl --user disable "$service"
            fi
            ;;
        macos)
            local plist_path="$HOME/Library/LaunchAgents/com.${SERVICE_NAME}.plist"
            if [[ -f "$plist_path" ]]; then
                launchctl unload -w "$plist_path"
            else
                log_warn "LaunchAgent plist not found: $plist_path"
            fi
            ;;
    esac
}

# Show service logs
show_service_logs() {
    local service="$1"
    local follow="${2:-false}"
    local lines="${3:-50}"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            local journal_args="--no-pager"
            
            if [[ "$follow" == "true" ]]; then
                journal_args="$journal_args -f"
            else
                journal_args="$journal_args -n $lines"
            fi
            
            if is_root; then
                journalctl $journal_args -u "$service"
            else
                journalctl --user $journal_args -u "$service"
            fi
            ;;
        macos)
            local log_file="/tmp/${SERVICE_NAME}.out"
            local err_file="/tmp/${SERVICE_NAME}.err"
            
            if [[ "$follow" == "true" ]]; then
                tail -f "$log_file" "$err_file" 2>/dev/null || {
                    log_warn "Log files not found. Service may not be running or configured for logging."
                }
            else
                (tail -n "$lines" "$log_file" 2>/dev/null || echo "No stdout log found") && echo
                (tail -n "$lines" "$err_file" 2>/dev/null || echo "No stderr log found")
            fi
            ;;
    esac
}

# Validation functions
validate_service_name() {
    local service="$1"
    
    if [[ -z "$service" ]]; then
        log_error "Service name cannot be empty"
        return 1
    fi
    
    if [[ ! "$service" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid service name: $service"
        log_error "Service names must contain only letters, numbers, dots, hyphens, and underscores"
        return 1
    fi
}

# Configuration helpers
get_config_dir() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/${SERVICE_NAME}"
}

get_data_dir() {
    echo "${XDG_DATA_HOME:-$HOME/.local/share}/${SERVICE_NAME}"
}

get_cache_dir() {
    echo "${XDG_CACHE_HOME:-$HOME/.cache}/${SERVICE_NAME}"
}

ensure_directory() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [[ ! -d "$dir" ]]; then
        log_verbose "Creating directory: $dir"
        mkdir -p "$dir"
        chmod "$mode" "$dir"
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log_error "Error occurred in script at line $line_number (exit code: $exit_code)"
    
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log_error "Call stack:"
        local frame=0
        while caller $frame; do
            ((frame++))
        done
    fi
    
    return $exit_code
}

# Version detection functions
get_service_binary() {
    local service="$1"
    # Default to the service name itself
    # Override this function in specific service implementations
    echo "$service"
}

is_service_installed() {
    local service="$1"
    local binary
    binary=$(get_service_binary "$service")
    
    # Check if binary is available in PATH
    if command -v "$binary" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check common installation paths
    local paths=(
        "/usr/local/bin/$binary"
        "/usr/bin/$binary"
        "/opt/$service/$binary"
        "/usr/local/$service/$binary"
    )
    
    for path in "${paths[@]}"; do
        if [[ -x "$path" ]]; then
            return 0
        fi
    done
    
    return 1
}

get_installed_version() {
    local service="$1"
    local binary version_output binary_path
    binary=$(get_service_binary "$service")
    
    if ! is_service_installed "$service"; then
        echo "not installed"
        return 1
    fi
    
    # Find the binary path
    if command -v "$binary" >/dev/null 2>&1; then
        binary_path="$binary"
    else
        # Check standard paths
        local paths=(
            "/usr/local/bin/$binary"
            "/usr/bin/$binary"
            "/opt/$service/$binary"
            "/usr/local/$service/$binary"
        )
        
        for path in "${paths[@]}"; do
            if [[ -x "$path" ]]; then
                binary_path="$path"
                break
            fi
        done
    fi
    
    if [[ -z "$binary_path" ]]; then
        echo "unknown"
        return 1
    fi
    
    # Try to get version from the binary
    version_output=$("$binary_path" --version 2>/dev/null | head -1)
    if [[ -n "$version_output" ]]; then
        echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
    else
        echo "unknown"
    fi
}

get_latest_version() {
    local service="$1"
    local github_repo="${SERVICE_GITHUB_REPO:-}"
    
    # Only check if we have network connectivity and a GitHub repo configured
    if [[ -z "$github_repo" ]] || ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "unknown"
        return 1
    fi
    
    # Try to get latest release from GitHub API
    if command -v curl >/dev/null 2>&1; then
        local api_url="https://api.github.com/repos/$github_repo/releases/latest"
        local latest_version
        latest_version=$(curl -s --connect-timeout 5 "$api_url" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/' 2>/dev/null)
        
        if [[ -n "$latest_version" && "$latest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
            echo "$latest_version"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Set up error trapping if DEBUG is enabled
if [[ "${DEBUG:-false}" == "true" ]]; then
    trap 'handle_error ${LINENO}' ERR
fi