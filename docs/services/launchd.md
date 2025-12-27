# macOS launchd Services

Managing services on macOS with launchd.

## Overview

launchd is macOS's service management system, similar to systemd on Linux. Service packages can include launchd configuration for macOS support.

## Plist Location

User launch agents go in `~/Library/LaunchAgents/`:

```
package-name/
└── config/
    └── macos/
        └── com.user.service-name.plist
```

During installation, the plist is symlinked or copied to `~/Library/LaunchAgents/`.

## Plist Template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.service-name</string>

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

## Common Commands

```bash
# Load service (start)
launchctl load ~/Library/LaunchAgents/com.user.service-name.plist

# Unload service (stop)
launchctl unload ~/Library/LaunchAgents/com.user.service-name.plist

# Check if running
launchctl list | grep service-name

# View logs
tail -f /tmp/service-name.out
tail -f /tmp/service-name.err
```

## Shell Aliases

Add to package's `shell/aliases`:

```bash
# Service management aliases
alias service-logs='tail -f /tmp/service-name.out'
alias service-status='launchctl list | grep service-name'
alias service-start='launchctl load ~/Library/LaunchAgents/com.user.service-name.plist'
alias service-stop='launchctl unload ~/Library/LaunchAgents/com.user.service-name.plist'
```

## Key Plist Options

### RunAtLoad

Start service when user logs in:

```xml
<key>RunAtLoad</key>
<true/>
```

### KeepAlive

Restart service if it exits:

```xml
<key>KeepAlive</key>
<true/>
```

Or only restart on failure:

```xml
<key>KeepAlive</key>
<dict>
    <key>SuccessfulExit</key>
    <false/>
</dict>
```

### WorkingDirectory

Set working directory:

```xml
<key>WorkingDirectory</key>
<string>/path/to/directory</string>
```

### StartInterval

Run periodically (in seconds):

```xml
<key>StartInterval</key>
<integer>3600</integer>
```

## Debugging

Check launchd logs:

```bash
# System log for launchd issues
log show --predicate 'subsystem == "com.apple.xpc.launchd"' --last 5m

# Check if plist is valid
plutil -lint ~/Library/LaunchAgents/com.user.service-name.plist
```

## See Also

- [systemd.md](systemd.md) - Linux service management
- [../templates/service-package/README.md](../templates/service-package/README.md) - Service package template
