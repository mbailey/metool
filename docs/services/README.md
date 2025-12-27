# Services

Service packages manage system services (systemd on Linux, launchd on macOS) through metool's package structure.

## Contents

- [systemd.md](systemd.md) - Linux systemd service management (user services with `--user`)
- [launchd.md](launchd.md) - macOS launchd service management (LaunchAgents)

## Overview

Service packages follow a standard pattern with unified commands for cross-platform service management:

- `install` - Install and configure the service
- `start` / `stop` / `restart` - Control service state
- `status` - Show service status
- `enable` / `disable` - Control autostart at boot/login
- `logs` - View service logs
- `config` - Manage service configuration

## Quick Reference

### Service Package Structure

```
service-name/
├── bin/
│   └── mt-service           # Main service management command
├── libexec/
│   └── service-name/        # Subcommands (start, stop, status, etc.)
├── lib/
│   └── service-functions.sh # Shared functions
├── config/
│   ├── dot-config/
│   │   └── systemd/user/    # User systemd units
│   └── macos/
│       └── com.service.plist # launchd configuration
└── shell/
    └── aliases              # Service management aliases
```

### Common Commands

```bash
mt-service status            # Check if service is running
mt-service start             # Start the service
mt-service logs -f           # Follow service logs
mt-service enable            # Start at boot/login
```

## See Also

- [docs/templates/service-package/](../templates/service-package/) - Complete service package template
- [docs/packages/README.md](../packages/README.md) - General package structure
