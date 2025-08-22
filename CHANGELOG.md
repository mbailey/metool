# Changelog

All notable changes to metool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- `mt git add` command for incremental repository management
  - Add repositories to nearest .repos.txt file
  - Interactive creation of .repos.txt if not found
  - Duplicate detection and skip logic
  - `--yes` flag for non-interactive mode
  - Support for MT_GIT_AUTO_ADD environment variable
- Tests for `mt git add` command
- Documentation for home directory repository workflow
- AI assistant support with AI.md replacing CLAUDE.md for broader compatibility
- CONVENTIONS.md as essential reading for AI assistants
- Comprehensive command listing in README core commands section

### Changed
- CONVENTIONS.md restored as main conventions file (from CONVENTIONS.legacy.md)
- README updated with accurate core command descriptions

### Removed
- External dependency management system (.repos.txt, .external/ directory)
- Package editing functionality from `mt edit` command

## [2024-12-19]

### Added
- MCP (Model Context Protocol) server v0.2.3
  - FastMCP integration for building MCP servers
  - Tool definitions for metool functionality
  - Installation and sync directory capabilities
  - Repository listing from repos.txt files
  - Project standards setup automation
- PyPI publishing for metool-mcp package

### Fixed
- FunctionTool not callable error in metool-mcp
- Version management for MCP releases

## [2024-11-13]

### Added
- `mt sync` command - Major repository synchronization feature with:
  - Two-phase sync strategy (new clones first, then updates)
  - GitHub shorthand syntax support (username/repo)
  - Host identity support for multiple git accounts (`_identity:username/repo`)
  - Protocol override capabilities (SSH/HTTPS)
  - Shared repositories strategy using symbolic links
  - Default repos.txt locations (~/.repos.txt, project .repos.txt)
  - Quiet and verbose modes
- External repository management via .repos.txt manifest files
- Comprehensive sync documentation and specifications

### Changed
- Enhanced repository cloning with canonical paths
- Improved error messages and user prompts

## [2024-11-12]

### Added
- `mt modules` command to list all metool modules
- `mt packages` command to list packages with parent modules
- `mt components` command to list package components
- Shell completion support for metool commands
- Package README.md editing support (`mt edit package/NAME`)
- Caching mechanism for package and module discovery (5-minute TTL)

### Changed
- Package editing logic to support explicit package/NAME syntax
- Command discovery to ignore directories without content
- Improved help messages and command descriptions

### Fixed
- Package discovery issues with non-existent directories
- Shell completion for package names
- Cache invalidation for module changes

## [2024-11-11]

### Added
- `mt clone` command for cloning repositories to canonical locations
- Clone status checking (shows if already cloned)
- Support for various git URL formats (GitHub, SSH, HTTPS)
- Installation confirmation with diff preview

### Changed
- Installation process to use relative symlinks instead of absolute paths
- Confirmation prompts to be case-insensitive (Y/n format)
- Enhanced error handling for missing repositories

### Fixed
- Symlink creation issues with relative paths
- Package installation detection
- Error messages for failed operations

## [2024-11-10]

### Added
- Comprehensive test suite using BATS framework
- Tests for core commands (cd, edit, install, reload, update)
- Path manipulation and normalization tests
- Mock environment support for testing

### Changed
- PATH manipulation to be more robust
- Directory change behavior to handle edge cases
- Function organization and error handling

### Fixed
- PATH cleanup issues when removing metool
- Directory navigation edge cases
- Function loading order problems

## [2024-11-09]

### Added
- Package component discovery (bin/, shell/, config/)
- Automatic shell sourcing for installed packages
- Support for dot-prefixed config directories
- Help command improvements

### Changed
- Installation process to handle multiple package types
- Configuration file handling for proper home directory placement
- Documentation structure improvements

### Fixed
- Config file installation to correct locations
- Shell file sourcing issues
- Package detection logic

## [2024-11-07]

### Added
- Core metool functionality
- `mt cd` command for navigation
- `mt edit` command for editing functions and files
- `mt install` command for package installation
- `mt reload` command to refresh environment
- `mt update` command for self-updates
- Basic package structure (bin/, shell/, config/)
- README with installation instructions

### Changed
- Self-bootstrapping architecture
- Modular design for packages and modules

## Notes on Versioning

This project has not used semantic versioning tags for the main codebase. The MCP component maintains its own versioning (currently at v0.2.3). Future releases should consider adopting semantic versioning for better release management.

For historical commits not listed here, see the git log for detailed change history.