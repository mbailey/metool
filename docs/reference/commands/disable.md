# mt disable

Disable systemd user service(s) while preserving the service file symlinks.

## Synopsis

```bash
mt disable PACKAGE[/SERVICE] [--now]
```

## Description

The `disable` command disables systemd service(s) and then immediately restores the service file symlinks that systemd removes. This solves the issue where `systemctl disable` removes all symlinks to a unit file, not just the enable symlinks.

After using `mt disable`, the service is disabled but the service file remains available, so you can re-enable it later without reinstalling the package.

## Arguments

- `PACKAGE` - The metool package containing the service(s)
- `SERVICE` - Optional specific service name (disables all services in package if omitted)

## Options

- `--now` - Also stop the service immediately after disabling
- `-h, --help` - Show help message

## Examples

Disable all services from a package:
```bash
mt disable work/backup-service
```

Disable a specific service:
```bash
mt disable work/monitoring/prometheus.service
```

Disable and stop immediately:
```bash
mt disable personal/vpn --now
```

## How It Works

1. Runs `systemctl --user disable` for the service(s)
2. Immediately runs `mt install PACKAGE` to restore service file symlinks
3. Optionally stops the service if `--now` is specified
4. Reloads systemd daemon to pick up any changes

## Why This Exists

When you run `systemctl --user disable` on a symlinked service file, systemd removes:
- The enable symlink from `~/.config/systemd/user/*.wants/` (expected)
- The service file symlink from `~/.config/systemd/user/` (unexpected)

This is documented systemd behavior but causes issues with metool's symlink-based approach. The `mt disable` command works around this by immediately restoring the service file symlink.

## See Also

- [enable](enable.md) - Enable services from a package
- [install](install.md) - Install package symlinks
- [systemd.md](../../systemd.md) - Details about systemd behavior with symlinks