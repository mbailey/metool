#!/bin/bash
# Bash completion for mt-service

_mt_service() {
    local cur prev words cword
    _init_completion || return

    local commands="install uninstall start stop restart status enable disable logs config"
    local global_opts="-h --help -v --verbose --debug"

    # Complete subcommands
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$commands $global_opts" -- "$cur"))
        return 0
    fi

    # Get the subcommand
    local subcommand="${words[1]}"

    # Handle global options
    case "$prev" in
        -h|--help|-v|--verbose|--debug)
            return 0
            ;;
    esac

    # Subcommand-specific completion
    case "$subcommand" in
        start)
            local start_opts="--no-enable --wait --verbose"
            COMPREPLY=($(compgen -W "$start_opts" -- "$cur"))
            ;;
        logs)
            case "$prev" in
                -n|--lines|--wait)
                    # Complete with numbers
                    COMPREPLY=($(compgen -W "10 50 100 500 1000" -- "$cur"))
                    ;;
                --since|--until)
                    # Complete with time expressions
                    COMPREPLY=($(compgen -W '"1 hour ago" "yesterday" "today"' -- "$cur"))
                    ;;
                --level)
                    # Complete with log levels
                    COMPREPLY=($(compgen -W "emerg alert crit err warning notice info debug" -- "$cur"))
                    ;;
                --grep)
                    # No completion for grep patterns
                    return 0
                    ;;
                *)
                    local logs_opts="-f --follow -n --lines --since --until --grep --level"
                    COMPREPLY=($(compgen -W "$logs_opts" -- "$cur"))
                    ;;
            esac
            ;;
        config)
            local config_opts="--edit --show --validate --reload"
            COMPREPLY=($(compgen -W "$config_opts" -- "$cur"))
            ;;
        status)
            local status_opts="--verbose --json"
            COMPREPLY=($(compgen -W "$status_opts" -- "$cur"))
            ;;
        install|uninstall|start|stop|restart|enable|disable)
            # These commands typically don't have additional options
            local common_opts="--verbose"
            COMPREPLY=($(compgen -W "$common_opts" -- "$cur"))
            ;;
        *)
            # Unknown subcommand
            return 0
            ;;
    esac

    return 0
}

# Register completion
complete -F _mt_service mt-service

# Also register for common service name patterns
complete -F _mt_service mt-prometheus
complete -F _mt_service mt-grafana
complete -F _mt_service mt-node-exporter
complete -F _mt_service mt-alertmanager