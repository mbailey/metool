_mt_complete_functions_and_executables() {
  local functions=$(compgen -A function -- "${COMP_WORDS[COMP_CWORD]}")
  local executables=$(compgen -c -- "${COMP_WORDS[COMP_CWORD]}")
  COMPREPLY=($(compgen -W "${functions} ${executables}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_modules_and_packages() {
  # Get only modules and packages from working set (no functions/executables)
  local module_names=""
  local package_names=""
  if type -t _mt_get_working_set_modules &>/dev/null; then
    module_names=$(_mt_get_working_set_modules 2>/dev/null | tr '\n' ' ')
  fi
  if type -t _mt_get_working_set_packages &>/dev/null; then
    package_names=$(_mt_get_working_set_packages 2>/dev/null | tr '\n' ' ')
  fi

  COMPREPLY=($(compgen -W "${module_names} ${package_names}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_executables() {
  COMPREPLY=($(compgen -c -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_functions() {
  COMPREPLY=($(compgen -A function -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_modules() {
  # Get modules from working set (MT-11)
  local module_names=""
  if type -t _mt_get_working_set_modules &>/dev/null; then
    module_names=$(_mt_get_working_set_modules 2>/dev/null | tr '\n' ' ')
  fi

  COMPREPLY=($(compgen -W "${module_names}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_packages() {
  # Get packages from working set (MT-11)
  local package_names=""
  if type -t _mt_get_working_set_packages &>/dev/null; then
    package_names=$(_mt_get_working_set_packages 2>/dev/null | tr '\n' ' ')
  fi

  COMPREPLY=($(compgen -W "${package_names}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Get all mt commands from libexec
  local mt_commands="cd deps doctor edit git module package reload update"
  if [[ -d "${MT_ROOT}/libexec" ]]; then
    local libexec_cmds=$(find "${MT_ROOT}/libexec" -type f -name "mt-*" -exec basename {} \; | sed 's/^mt-//')
    mt_commands+=" ${libexec_cmds}"
  fi

  if [[ ${COMP_CWORD} == 1 ]]; then
    # Complete with commands and global flags
    if [[ "${cur}" == -* ]]; then
      COMPREPLY=($(compgen -W "-d --debug -h --help" -- "${cur}"))
    else
      COMPREPLY=($(compgen -W "${mt_commands}" -- "${cur}"))
    fi
  elif [[ ${prev} == "cd" ]]; then
    _mt_complete_modules_and_packages
  elif [[ ${prev} == "edit" ]]; then
    _mt_complete_functions_and_executables
  elif [[ ${prev} == "module" ]]; then
    # Complete with module subcommands
    local module_subcommands="list add remove edit update"
    COMPREPLY=($(compgen -W "${module_subcommands}" -- "${cur}"))
  elif [[ ${COMP_WORDS[1]} == "module" && ${prev} == "remove" ]]; then
    # Complete with module names for removal
    _mt_complete_modules
  elif [[ ${COMP_WORDS[1]} == "module" && ${prev} == "edit" ]]; then
    # Complete with module names for editing
    _mt_complete_modules
  elif [[ ${COMP_WORDS[1]} == "module" && ${prev} == "update" ]]; then
    # Complete with module names for updating, or --all flag
    if [[ "${cur}" == -* ]]; then
      COMPREPLY=($(compgen -W "-a --all --help" -- "${cur}"))
    else
      _mt_complete_modules
    fi
  elif [[ ${prev} == "package" ]]; then
    # Complete with package subcommands
    local package_subcommands="list add remove edit install uninstall service new validate diff"
    COMPREPLY=($(compgen -W "${package_subcommands}" -- "${cur}"))
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "remove" ]]; then
    # Complete with package names for removal
    _mt_complete_packages
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "edit" ]]; then
    # Complete with package names for editing
    _mt_complete_packages
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "install" ]]; then
    # Complete with package names for installation or flags
    if [[ "${cur}" == -* ]]; then
      COMPREPLY=($(compgen -W "--no-bin --no-config --no-shell --help" -- "${cur}"))
    else
      _mt_complete_packages
    fi
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "uninstall" ]]; then
    # Complete with package names for uninstallation or flags
    if [[ "${cur}" == -* ]]; then
      COMPREPLY=($(compgen -W "--no-bin --no-config --no-shell --help" -- "${cur}"))
    else
      _mt_complete_packages
    fi
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "service" ]]; then
    # Complete with service subcommands
    local service_subcommands="start stop restart status enable disable logs list"
    COMPREPLY=($(compgen -W "${service_subcommands}" -- "${cur}"))
  elif [[ ${COMP_WORDS[1]} == "package" && ${COMP_WORDS[2]} == "service" ]]; then
    # Complete with package names for service commands
    _mt_complete_packages
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "diff" ]]; then
    # First arg after diff: package name
    if [[ "${cur}" == -* ]]; then
      COMPREPLY=($(compgen -W "-c --content -q --quiet -a --all --help" -- "${cur}"))
    else
      _mt_complete_packages
    fi
  elif [[ ${COMP_WORDS[1]} == "package" && ${COMP_WORDS[2]} == "diff" ]]; then
    # Complete with modules for from/to arguments, or flags
    if [[ "${cur}" == -* ]]; then
      COMPREPLY=($(compgen -W "-c --content -q --quiet -a --all --help" -- "${cur}"))
    else
      _mt_complete_modules
    fi
  elif [[ ${COMP_WORDS[1]} == "package" && ${prev} == "validate" ]]; then
    # Complete with package names or directories for validation
    _mt_complete_packages
  elif [[ ${prev} == "deps" ]]; then
    # Complete with deps flags
    local deps_flags="--install --fix --auto --help"
    COMPREPLY=($(compgen -W "${deps_flags}" -- "${cur}"))
  elif [[ ${prev} == "git" ]]; then
    # Complete with git subcommands
    local git_subcommands="add clone pull push repos trusted"
    COMPREPLY=($(compgen -W "${git_subcommands}" -- "${cur}"))
  elif [[ ${COMP_WORDS[1]} == "git" && ${prev} == "repos" ]]; then
    # Complete with repos flags directly (no subcommands)
    local repos_flags="-r --recursive -c --columnise --help"
    COMPREPLY=($(compgen -W "${repos_flags}" -- "${cur}"))
    # Also add directory completion
    local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${dirs[@]}")
  elif [[ ${COMP_WORDS[1]} == "git" && ${prev} == "pull" ]]; then
    # Complete with pull flags, directories and repos.txt files
    local pull_flags="--quick --dry-run --protocol --verbose --help"
    COMPREPLY=($(compgen -W "${pull_flags}" -- "${cur}"))
    # Also add directory completion
    local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${dirs[@]}")
    # Add repos.txt file completion
    local txtfiles=($(compgen -f -X '!*.txt' -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${txtfiles[@]}")
  elif [[ ${COMP_WORDS[1]} == "git" && ${prev} == "push" ]]; then
    # Complete with push flags, directories and repos.txt files
    local push_flags="--dry-run --force --verbose --help"
    COMPREPLY=($(compgen -W "${push_flags}" -- "${cur}"))
    # Also add directory completion
    local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${dirs[@]}")
    # Add repos.txt file completion
    local txtfiles=($(compgen -f -X '!*.txt' -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${txtfiles[@]}")
  elif [[ ${COMP_WORDS[1]} == "git" && ${prev} == "trusted" ]]; then
    # Complete with trusted flags and directories
    local trusted_flags="-l --list --help"
    COMPREPLY=($(compgen -W "${trusted_flags}" -- "${cur}"))
    # Also add directory completion
    local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${dirs[@]}")
  elif [[ ${COMP_WORDS[1]} == "git" && ${COMP_WORDS[2]} == "pull" ]]; then
    # Handle git pull subcommand arguments
    case "${prev}" in
      --protocol|-p)
        # Complete with protocol options
        COMPREPLY=($(compgen -W "git https" -- "${cur}"))
        ;;
      *)
        # Complete with directories, files, and remaining flags
        local pull_flags="--quick --dry-run --protocol --verbose --help"
        COMPREPLY=($(compgen -W "${pull_flags}" -- "${cur}"))
        local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
        COMPREPLY+=("${dirs[@]}")
        local txtfiles=($(compgen -f -X '!*.txt' -- "${cur}" 2>/dev/null))
        COMPREPLY+=("${txtfiles[@]}")
        ;;
    esac
  elif [[ ${COMP_WORDS[1]} == "git" && ${COMP_WORDS[2]} == "push" ]]; then
    # Handle git push subcommand arguments
    # Complete with directories, files, and remaining flags
    local push_flags="--dry-run --force --verbose --help"
    COMPREPLY=($(compgen -W "${push_flags}" -- "${cur}"))
    local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${dirs[@]}")
    local txtfiles=($(compgen -f -X '!*.txt' -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${txtfiles[@]}")
  elif [[ ${COMP_WORDS[1]} == "git" && ${COMP_WORDS[2]} == "clone" ]]; then
    # Handle git clone subcommand arguments
    case "${prev}" in
      --include-identity-in-path)
        # After this flag, we expect a repository
        compopt -o default
        COMPREPLY=()
        ;;
      *)
        # Check if we've already used --include-identity-in-path
        local has_identity_flag=false
        for word in "${COMP_WORDS[@]:3:$((COMP_CWORD-3))}"; do
          if [[ "$word" == "--include-identity-in-path" ]]; then
            has_identity_flag=true
            break
          fi
        done
        
        # Provide appropriate completions
        if [[ "${cur}" == -* ]]; then
          # Complete with remaining flags
          local clone_flags="--help -h"
          if [[ "$has_identity_flag" != true ]]; then
            clone_flags="--include-identity-in-path $clone_flags"
          fi
          COMPREPLY=($(compgen -W "${clone_flags}" -- "${cur}"))
        else
          # Default completion for repository names
          compopt -o default
          COMPREPLY=()
        fi
        ;;
    esac
  fi
}

complete -F _mt_completions mt
