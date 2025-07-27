# AI.md

This file provides guidance to AI assistants when working with metool.

## Essential Reading

**CRITICAL**: Before modifying any metool package, you MUST read:
- CONVENTIONS.md
- `.ai/package-structure.md` - Required package directory structure

## Commands
- Install: `git clone https://github.com/mbailey/metool.git && source metool/shell/mt && mt install`
- Reload: `mt reload` - Reloads metool
- Update: `mt update` - Updates metool from git

## Style Guidelines
- Files: Use `.sh` extension for library files
- Functions: Prefix internal functions with `_mt_`, public commands use `mt` subcommand pattern
- Variables: Prefix environment variables with `MT_` (e.g., `MT_PKG_DIR`, `MT_LOG_LEVEL`)
- Error handling: Use non-zero exit codes for failures, `_mt_error` for errors
- Paths: Use absolute paths with `realpath` for canonical path resolution
- Logging: Use `_mt_log` with levels (DEBUG, INFO, WARNING, ERROR)
- Documentation: Add function comments above declarations, include usage examples
- Compatibility: Write for Bash shell, follow POSIX conventions where possible
- Code structure: Keep functions modular and focused on specific tasks

## Project Organization
- `lib/`: Core library files organized by function
- `shell/`: Shell configuration files and main mt script
- Packages follow organized structure with bin/, config/, shell/, lib/, docs/ directories
