# Metool AI Guide

This guide helps AI agents understand and work effectively with metool.

## What is Metool?

Metool is the core configuration management tool that uses GNU Stow to manage symlinks. It operates on **metool modules** - separate git repositories that contain packages.

## Core Concepts

### Metool (the tool)
- Core tool for managing configuration packages
- Provides the `mt` command interface
- Defines conventions and operations

### Metool Modules
- Separate git repositories containing packages
- Examples: `metool-packages`, `metool-packages-dev`, `metool-packages-personal`
- Cloned/managed via `mt sync`

### Packages
- Self-contained units within modules
- Follow standard structure: `bin/`, `shell/`, `config/`, `lib/`, `libexec/`
- Installed via `mt install <module>/<package>`

## Essential Reading

Always read these metool documentation files:
- @docs/reference/commands/README.md - Complete command reference
- @docs/conventions/package-structure.md - Package structure conventions
- @docs/templates/service-package/README.md - Service package template (for service packages)

## Key Points for AI Agents

1. **Script Usage**: Use `mtbin` wrapper when calling from scripts (not `mt`)
2. **Package Structure**: Follow conventions in `docs/conventions/package-structure.md`
3. **Service Packages**: For packages managing system services (systemd/launchd), use the template in `docs/templates/service-package/`. This provides unified command structure with install, start, stop, restart, status, enable, disable, logs, and config subcommands.
4. **Naming**: Use lowercase-with-hyphens for packages
5. **Documentation**: Every package needs a README.md

## Quick Reference

- `mt install <module>/<package>` - Install a package
- `mt sync <module>` - Clone/update module repositories
- `mt cd` - Navigate to metool directories
- See full command list in docs/reference/commands/README.md