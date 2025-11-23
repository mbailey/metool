# Metool Template Strategy

## Overview

Metool uses a layered template approach where templates can be composed:
- **templates/package** - Base package structure
- **templates/package-service** - Service-specific additions (overlay)

## Base Package Template

Location: `templates/package/`

Provides the fundamental structure for all metool packages:

```
package/
├── README.md                 # Package documentation template with {PACKAGE_NAME} placeholders
├── SKILL.md.example          # Optional Claude Code skill integration
├── bin/
│   └── example-tool          # Example executable with help, argument parsing
├── shell/
│   ├── functions             # Shell functions with extensive documentation
│   ├── aliases               # Command aliases with examples
│   ├── environment           # Environment variables with defaults
│   ├── path                  # PATH modifications using mt_path_prepend/append
│   └── completions/
│       └── example-tool.bash # Bash completion for the example tool
├── config/
│   └── dot-config/
│       └── package-name/
│           └── config.yml    # Configuration file example
└── lib/
    └── helpers.sh            # Library functions (sourced, not executed)
```

All shell files include extensive inline documentation explaining:
- What the file is for
- Naming conventions
- Best practices
- Multiple commented examples
- TODO markers for customization

## Service Package Template (Overlay)

Location: `templates/package-service/`

Adds service management capabilities to a package. This template is designed to be:
1. **Applied on top of base template** when creating a new service package
2. **Applied to existing package** to add service management

### Service-Specific Additions

```
package-service/
├── README.md                 # DOCUMENTATION about this template (not a package README!)
├── bin/
│   └── mt-service            # Service management command dispatcher
├── libexec/
│   └── service-name/         # Service subcommands
│       ├── start
│       ├── stop
│       ├── status
│       └── logs
├── lib/
│   └── service-functions.sh  # Service management library (systemd/launchd helpers)
├── config/
│   ├── dot-config/
│   │   └── systemd/
│   │       └── user/
│   │           └── service-name.service
│   └── macos/
│       └── com.service-name.plist
└── shell/
    ├── aliases               # Service-specific aliases (service-logs, service-restart, etc.)
    └── completions/
        └── mt-service.bash   # Completion for mt-service command
```

### Key Design Decisions

1. **README.md in package-service**: Currently contains comprehensive documentation about the service template itself, including version detection features, implementation patterns, and examples. This is NOT a template for a package README.

   **Options:**
   - Rename to `TEMPLATE.md` or `GUIDE.md` to clarify it's documentation
   - Move to `docs/service-package-guide.md` in the main metool repo
   - Keep as README but add prominent header clarifying it's template documentation

2. **Shell files are additive**: The service template's shell/aliases and shell/completions don't replace the base package's files - they add service-specific commands alongside the base package's example-tool.

3. **No duplication of base structure**: The service template doesn't include:
   - bin/example-tool (base package has this)
   - Generic functions/aliases for the base package
   - Basic config structure (base package has this)

## Template Application Strategy

### Creating a new service package:
```bash
mt package new my-service --service
# Applies: templates/package + templates/package-service
```

### Adding service to existing package:
```bash
mt package add-service my-existing-package
# Applies: templates/package-service (overlay)
```

## Placeholder Substitution

Templates use `{PACKAGE_NAME}` placeholders for:
- Package names
- Command names
- Function/variable prefixes
- Documentation

When applying templates, these should be replaced with actual package names.

## Documentation in Templates

Following Mike's direction: **Templates ARE documentation**. Each template file includes:
- Header comments explaining the file's purpose
- Conventions and best practices
- Multiple commented examples
- TODO markers for customization

This approach provides:
- Self-documenting templates
- Learning by example
- Reduced duplication (one source of truth)
- Context-aware guidance

## Future Enhancements

Potential commands to implement:
- `mt package new <name>` - Create from base template
- `mt package new <name> --service` - Create with service overlay
- `mt package add-service <name>` - Add service to existing package
- Template variable substitution (replace {PACKAGE_NAME})
