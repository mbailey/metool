#!/usr/bin/env bash
# Bash completion for {PACKAGE_NAME} example-tool
# [TODO: Replace {PACKAGE_NAME} and customize for your tool]
#
# This file provides tab-completion for your package's command-line tools.
#
# HOW IT WORKS:
#   - When user presses TAB, bash calls the completion function
#   - The function inspects current word being typed (COMP_WORDS)
#   - It returns suggestions in COMPREPLY array
#
# COMMON PATTERNS:
#
# 1. Complete subcommands (like git has add, commit, push):
#    COMPREPLY=( $(compgen -W "start stop status restart" -- "$cur") )
#
# 2. Complete file paths:
#    COMPREPLY=( $(compgen -f -- "$cur") )
#
# 3. Complete directory paths only:
#    COMPREPLY=( $(compgen -d -- "$cur") )
#
# 4. Complete from custom list:
#    local options="--verbose --quiet --help"
#    COMPREPLY=( $(compgen -W "$options" -- "$cur") )
#
# 5. Dynamic completion from command output:
#    local items=$(your-command --list-items)
#    COMPREPLY=( $(compgen -W "$items" -- "$cur") )
#
# VARIABLES AVAILABLE:
#   COMP_WORDS - array of all words on command line
#   COMP_CWORD - index of current word being completed
#   cur - current word being typed
#   prev - previous word on command line

_example_tool_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # [TODO: Customize completion logic below]

    # Global options available for all subcommands
    local global_opts="--help --verbose --quiet"

    # If completing first argument (subcommand)
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local subcommands="start stop status restart config"
        COMPREPLY=( $(compgen -W "$subcommands $global_opts" -- "$cur") )
        return 0
    fi

    # Subcommand-specific completion
    local subcommand="${COMP_WORDS[1]}"
    case "$subcommand" in
        start|stop|restart)
            # Example: complete service names
            # local services=$(list-services)
            # COMPREPLY=( $(compgen -W "$services" -- "$cur") )
            COMPREPLY=( $(compgen -W "$global_opts" -- "$cur") )
            ;;
        status)
            # Example: complete with format options
            local formats="--json --yaml --short"
            COMPREPLY=( $(compgen -W "$formats $global_opts" -- "$cur") )
            ;;
        config)
            # Example: complete file paths
            COMPREPLY=( $(compgen -f -- "$cur") )
            ;;
        *)
            # Default: just global options
            COMPREPLY=( $(compgen -W "$global_opts" -- "$cur") )
            ;;
    esac

    return 0
}

# Register the completion function for your tool
# [TODO: Replace 'example-tool' with your actual command name]
complete -F _example_tool_completion example-tool
