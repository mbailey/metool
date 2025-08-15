# Service Package Template

This template provides a complete foundation for creating metool service management packages using the libexec pattern with comprehensive version detection.

## Features

- **Cross-platform Support**: Works on Linux (systemd) and macOS (launchd)
- **Service Management**: Start, stop, restart, enable, disable services
- **Status Monitoring**: Comprehensive status reporting with version detection
- **Log Management**: View and follow service logs
- **Configuration**: Service configuration file management
- **Shell Integration**: Aliases and bash completion
- **JSON Output**: Machine-readable status and configuration data
- **Version Detection**: Automatic binary discovery and version checking

## Directory Structure

```
service-name/
├── README.md                    # Package documentation
├── bin/
│   └── mt-service               # Main service management command
├── libexec/
│   └── service-name/            # Service subcommands
│       ├── install              # Install and configure service
│       ├── uninstall            # Remove service and configuration
│       ├── start                # Start service
│       ├── stop                 # Stop service
│       ├── restart              # Restart service
│       ├── status               # Show service status
│       ├── enable               # Enable service at boot/login
│       ├── disable              # Disable service at boot/login
│       ├── logs                 # View service logs
│       └── config               # Manage service configuration
├── lib/
│   └── service-functions.sh     # Shared functions for service management
├── config/
│   ├── etc/
│   │   └── systemd/
│   │       └── system/          # System-wide systemd units (requires root)
│   │           └── service-name.service
│   ├── dot-config/
│   │   ├── systemd/
│   │   │   └── user/            # User systemd units
│   │   │       └── service-name.service
│   │   └── service-name/        # Service configuration files
│   │       └── config.yml
│   └── macos/
│       └── com.service-name.plist  # macOS launchd configuration
├── shell/
│   ├── aliases                  # Service management aliases
│   └── completions/
│       └── mt-service.bash      # Bash completion
└── docs/
    └── service-management.md    # Detailed service documentation
```

## Version Detection

The template includes comprehensive version detection capabilities developed from the Prometheus package implementation:

### New Functions in `lib/service-functions.sh`:

- **`get_service_binary(service)`** - Returns the binary name for the service (override in specific implementations)
- **`is_service_installed(service)`** - Checks if the service binary is installed in common paths
- **`get_installed_version(service)`** - Extracts version from binary `--version` output using regex
- **`get_latest_version(service)`** - Fetches latest version from GitHub API (requires `SERVICE_GITHUB_REPO`)

### Configuration Variables:

Add to your service's configuration:

```bash
# In your main service script or configuration
export SERVICE_GITHUB_REPO="owner/repository"  # For version checking (optional)
```

### Enhanced Status Output:

The status command now includes:
- **Installation detection**: Checks multiple common installation paths
- **Version display**: Shows installed version with visual indicators  
- **Update notifications**: Compares with latest GitHub release (verbose mode)
- **JSON support**: Includes `installed`, `version`, and `latest_version` fields

### Status Indicators:

- `✓` - Version is up to date with latest GitHub release
- `❌ not installed` - Service binary not found in any common path
- `(latest: X.Y.Z)` - Shows available update in verbose mode
- Green version number - Successfully detected installed version

### Binary Discovery:

The template checks these paths automatically:
- `/usr/local/bin/`
- `/usr/bin/`
- `/opt/service/`
- `/usr/local/service/`
- Any location in `$PATH`

## Implementation Pattern

### Main Command (bin/mt-service)

The main command dispatches to libexec subcommands:

```bash
#!/usr/bin/env bash
# mt-service - Unified service management for ServiceName
set -o nounset -o pipefail

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Export for subcommands
export SERVICE_PACKAGE_DIR="$PACKAGE_DIR"
export SERVICE_NAME="service-name"

# Source shared functions
source "$PACKAGE_DIR/lib/service-functions.sh"

show_help() {
    cat << EOF
mt-service - Manage ServiceName system service

USAGE:
    mt-service <COMMAND> [OPTIONS]

COMMANDS:
    install     Install and configure the service
    uninstall   Remove service and configuration
    start       Start the service
    stop        Stop the service
    restart     Restart the service
    status      Show service status
    enable      Enable service at boot/login
    disable     Disable service at boot/login
    logs        View service logs
    config      Manage service configuration

GLOBAL OPTIONS:
    -h, --help     Show help information
    -v, --verbose  Enable verbose output
    --debug        Enable debug output

EXAMPLES:
    mt-service install              # Install service
    mt-service start                # Start service
    mt-service logs -f              # Follow service logs
    mt-service config --edit        # Edit configuration

EOF
}

main() {
    local subcommand=""
    local subcommand_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                return 0
                ;;
            -v|--verbose)
                export VERBOSE=true
                shift
                ;;
            --debug)
                export DEBUG=true
                export VERBOSE=true
                shift
                ;;
            install|uninstall|start|stop|restart|status|enable|disable|logs|config)
                subcommand="$1"
                shift
                subcommand_args=("$@")
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                echo "Run 'mt-service --help' for usage information."
                return 1
                ;;
            *)
                log_error "Unknown command: $1"
                echo "Run 'mt-service --help' for usage information."
                return 1
                ;;
        esac
    done

    if [[ -z "$subcommand" ]]; then
        subcommand="status"
    fi

    # Execute subcommand
    local subcommand_path="$PACKAGE_DIR/libexec/$SERVICE_NAME/$subcommand"
    
    if [[ ! -f "$subcommand_path" ]]; then
        log_error "Subcommand not found: $subcommand"
        return 1
    fi

    if [[ ! -x "$subcommand_path" ]]; then
        log_error "Subcommand not executable: $subcommand"
        return 1
    fi

    "$subcommand_path" "${subcommand_args[@]}"
}

main "$@"
```

### Shared Functions (lib/service-functions.sh)

Common functions used by all subcommands:

```bash
#!/usr/bin/env bash
# Shared functions for service management

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[${SERVICE_NAME}]${NC} $*"
}

error() {
    echo -e "${RED}[${SERVICE_NAME}]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[${SERVICE_NAME}]${NC} $*"
}

info() {
    echo -e "${BLUE}[${SERVICE_NAME}]${NC} $*"
}

debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo -e "${YELLOW}[DEBUG]${NC} $*"
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

# Service status helpers
service_is_active() {
    local service="$1"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            if is_root; then
                systemctl is-active "$service" &>/dev/null
            else
                systemctl --user is-active "$service" &>/dev/null
            fi
            ;;
        macos)
            launchctl list | grep -q "$service"
            ;;
    esac
}

# Get service PID
get_service_pid() {
    local service="$1"
    local os=$(detect_os)
    
    case "$os" in
        linux)
            if is_root; then
                systemctl show "$service" --property MainPID --value
            else
                systemctl --user show "$service" --property MainPID --value
            fi
            ;;
        macos)
            launchctl list | grep "$service" | awk '{print $1}' | grep -v "^-$"
            ;;
    esac
}
```

### Service Subcommands

Each subcommand in `libexec/service-name/` handles a specific operation.

Example: `libexec/service-name/start`

```bash
#!/usr/bin/env bash
# Start the service
set -o nounset -o pipefail

source "$SERVICE_PACKAGE_DIR/lib/service-functions.sh"

show_help() {
    cat << EOF
Start the $SERVICE_NAME service

USAGE:
    mt-service start [OPTIONS]

OPTIONS:
    -h, --help      Show help
    --foreground    Run in foreground (don't detach)
    --verbose       Show detailed output

EOF
}

main() {
    local foreground=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                return 0
                ;;
            --foreground)
                foreground=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    local os=$(detect_os)
    
    # Check if already running
    if service_is_active "$SERVICE_NAME"; then
        warn "Service is already running"
        return 0
    fi

    log "Starting $SERVICE_NAME service..."
    
    case "$os" in
        linux)
            if is_root; then
                systemctl start "$SERVICE_NAME"
            else
                systemctl --user start "$SERVICE_NAME"
            fi
            ;;
        macos)
            launchctl start "com.$SERVICE_NAME"
            ;;
        *)
            error "Unsupported operating system"
            return 1
            ;;
    esac

    # Verify startup
    sleep 1
    if service_is_active "$SERVICE_NAME"; then
        log "Service started successfully"
        if [[ "$VERBOSE" == "true" ]]; then
            "$SERVICE_PACKAGE_DIR/libexec/$SERVICE_NAME/status"
        fi
    else
        error "Failed to start service"
        return 1
    fi
}

main "$@"
```

## Service Unit Files

### Linux systemd (config/dot-config/systemd/user/service-name.service)

```ini
[Unit]
Description=ServiceName - Brief description
Documentation=https://github.com/owner/service-name
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/service-binary --config %E/service-name/config.yml
Restart=on-failure
RestartSec=10

# Security settings
NoNewPrivileges=true
PrivateTmp=true

# Logging
StandardOutput=journal
StandardError=journal

# Environment
Environment="SERVICE_HOME=%E/service-name"
EnvironmentFile=-%E/service-name/environment

[Install]
WantedBy=default.target
```

### macOS launchd (config/macos/com.service-name.plist)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.service-name</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/service-binary</string>
        <string>--config</string>
        <string>/Users/USERNAME/.config/service-name/config.yml</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/tmp/service-name.out</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/service-name.err</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>SERVICE_HOME</key>
        <string>/Users/USERNAME/.config/service-name</string>
    </dict>
</dict>
</plist>
```

## Shell Aliases (shell/aliases)

```bash
# Service management aliases
alias service-logs='mt-service logs -f'
alias service-status='mt-service status'
alias service-restart='mt-service restart'

# Quick access to config
alias service-config='$EDITOR ~/.config/service-name/config.yml'
```

## Best Practices

1. **OS Compatibility**: Always support both Linux (systemd) and macOS (launchd)
2. **User vs System**: Default to user services unless root is required
3. **Logging**: Use system logging (journald/Console.app)
4. **Configuration**: Store in `~/.config/service-name/`
5. **Error Handling**: Provide clear error messages and recovery steps
6. **Idempotency**: Commands should be safe to run multiple times
7. **Status Feedback**: Always show clear status after operations

## Testing

Include tests for:
- Installation on fresh system
- Service start/stop/restart
- Configuration changes
- Log output
- Error conditions
- Uninstall cleanup

## Documentation Requirements

Each service package should document:
1. What the service does
2. System requirements
3. Configuration options
4. Troubleshooting guide
5. Security considerations
6. Performance tuning

## Usage Examples

### Basic Status with Version Detection
```bash
mt-service status
# Output: service service: ● Active
#         Version: 1.2.3 ✓
#         PID: 12345
```

### Verbose Status with Update Checking
```bash
mt-service status --verbose
# Shows detailed information including:
# - Installation path
# - Current version vs latest available
# - Configuration directories
# - Service details
```

### JSON Status for Automation
```bash
mt-service status --json
# Returns JSON with installed, version, latest_version fields:
# {
#   "service": "my-service",
#   "installed": true,
#   "version": "1.2.3",
#   "latest_version": "1.2.4",
#   "active": true,
#   "enabled": true
# }
```

## Customizing Version Detection

For services with non-standard binary names:

```bash
# Override in your specific implementation
get_service_binary() {
    local service="$1"
    case "$service" in
        node-exporter) echo "node_exporter" ;;
        blackbox-exporter) echo "blackbox_exporter" ;;
        *) echo "$service" ;;
    esac
}
```

## Example Services

Study these existing service packages:
- `packages/yubikey` - Simple service management
- `packages/prometheus` - Multiple related services with advanced version detection
- Voice Mode - Complex service with dependencies