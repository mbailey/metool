# Systemd Services in Metool Packages

## Overview

Metool packages can include systemd user services by placing them in the `config/dot-config/systemd/user/` directory. These service files will be symlinked to `~/.config/systemd/user/` when the package is installed.

## Important Behavior: systemctl disable

When you run `systemctl --user disable <service>` on a symlinked service file, systemd will remove **ALL** symlinks to that unit file, including:

1. The symlink in the `*.wants/` directory (expected)
2. The service file symlink itself in `~/.config/systemd/user/` (unexpected but documented)

This is documented systemd behavior - it removes all symlinks pointing to the unit file, not just the ones created by `systemctl enable`.

## Implications for Metool

After running `systemctl --user disable` on a service from a metool package:
- The service file symlink will be removed from `~/.config/systemd/user/`
- You'll need to run `mt install <package>` again to restore the symlink
- Then you can use `systemctl --user enable` if you want to re-enable the service

## Example Workflow

```bash
# Install package with systemd service
mt install work/my-service

# Enable and start the service
systemctl --user enable --now my-service.service

# Later, disable the service
systemctl --user disable my-service.service
# Note: This removes the service file symlink!

# To use the service again, reinstall the package
mt install work/my-service

# Then enable if desired
systemctl --user enable my-service.service
```

## Best Practices

1. **Document the behavior** in your package README if it includes systemd services
2. **Consider aliases** for common operations:
   ```bash
   # In shell/aliases
   alias myservice-reinstall='mt install work/my-service && systemctl --user daemon-reload'
   ```
3. **Use stop instead of disable** when you just want to temporarily stop a service:
   ```bash
   systemctl --user stop my-service.service  # Stops but doesn't remove symlinks
   ```

## Alternative Approaches

While metool currently only supports symlinking, future versions might consider:
- Copying service files instead of symlinking them
- Using `systemctl link` (though testing shows this doesn't prevent the issue)
- Post-install hooks to handle service registration

For now, the simplest approach is to document the need to reinstall after disabling.