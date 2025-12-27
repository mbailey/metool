# mt enable

Enable systemd user service(s) from a metool package.

## Synopsis

```bash
mt enable PACKAGE[/SERVICE] [--now]
```

## Description

The `enable` command ensures a package is installed and then enables its systemd service(s). Unlike using `systemctl enable` directly, this command first verifies the package is properly installed with all its symlinks.

This solves the common issue where `systemctl disable` removes service file symlinks, requiring a reinstall before the service can be enabled again.

## Arguments

- `PACKAGE` - The metool package containing the service(s)
- `SERVICE` - Optional specific service name (enables all services in package if omitted)

## Options

- `--now` - Also start the service immediately after enabling
- `-h, --help` - Show help message

## Examples

Enable all services from a package:
```bash
mt enable work/backup-service
```

Enable a specific service:
```bash
mt enable work/monitoring/prometheus.service
```

Enable and start immediately:
```bash
mt enable personal/vpn --now
```

## How It Works

1. Ensures the package is installed (`mt install PACKAGE`)
2. Runs `systemctl --user enable` for the service(s)
3. Optionally starts the service if `--now` is specified
4. Reloads systemd daemon to pick up any changes

## Service File Location

Services should be placed in the package's `config/dot-config/systemd/user/` directory. When the package is installed, these are symlinked to `~/.config/systemd/user/`.

## See Also

- [disable](disable.md) - Disable services while preserving service files
- [install](install.md) - Install package symlinks