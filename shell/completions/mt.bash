_mt_complete_functions_and_executables() {
  local functions=$(compgen -A function -- "${COMP_WORDS[COMP_CWORD]}")
  local executables=$(compgen -c -- "${COMP_WORDS[COMP_CWORD]}")
  COMPREPLY=($(compgen -W "${functions} ${executables}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_executables() {
  COMPREPLY=($(compgen -c -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_functions() {
  COMPREPLY=($(compgen -A function -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_modules() {
  local modules=$(_mt_get_modules 2>/dev/null)
  local module_names=""
  
  while IFS=$'\t' read -r module_name _; do
    module_names+=" ${module_name}"
  done <<< "$modules"
  
  COMPREPLY=($(compgen -W "${module_names}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_complete_packages() {
  local packages=$(_mt_get_packages 2>/dev/null)
  local package_names=""
  
  while IFS=$'\t' read -r package_name _ _; do
    package_names+=" ${package_name}"
  done <<< "$packages"
  
  COMPREPLY=($(compgen -W "${package_names}" -- "${COMP_WORDS[COMP_CWORD]}"))
}

_mt_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Get all mt commands from libexec  
  local mt_commands="cd edit git install modules packages components reload update deps clean"
  if [[ -d "${MT_ROOT}/libexec" ]]; then
    local libexec_cmds=$(find "${MT_ROOT}/libexec" -type f -name "mt-*" -exec basename {} \; | sed 's/^mt-//')
    mt_commands+=" ${libexec_cmds}"
  fi

  if [[ ${COMP_CWORD} == 1 ]]; then
    COMPREPLY=($(compgen -W "${mt_commands}" -- "${cur}"))
  elif [[ ${prev} == "cd" ]]; then
    _mt_complete_functions_and_executables
  elif [[ ${prev} == "edit" ]]; then
    _mt_complete_functions_and_executables
  elif [[ ${prev} == "install" || ${prev} == "stow" ]]; then
    # Complete with package names
    _mt_complete_packages
  elif [[ ${prev} == "modules" ]]; then
    # Complete with module names
    _mt_complete_modules
  elif [[ ${prev} == "packages" ]]; then
    # Complete with module names (to filter packages by module)
    _mt_complete_modules
  elif [[ ${prev} == "components" ]]; then
    # Complete with package names (to filter components by package)
    _mt_complete_packages
  elif [[ ${prev} == "deps" ]]; then
    # Complete with deps flags
    local deps_flags="--install --help"
    COMPREPLY=($(compgen -W "${deps_flags}" -- "${cur}"))
  elif [[ ${prev} == "git" ]]; then
    # Complete with git subcommands
    local git_subcommands="clone repos sync trusted"
    COMPREPLY=($(compgen -W "${git_subcommands}" -- "${cur}"))
  elif [[ ${COMP_WORDS[1]} == "git" && ${prev} == "repos" ]]; then
    # Complete with repos flags directly (no subcommands)
    local repos_flags="-r --recursive -c --columnise --help"
    COMPREPLY=($(compgen -W "${repos_flags}" -- "${cur}"))
    # Also add directory completion
    local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
    COMPREPLY+=("${dirs[@]}")
  elif [[ ${COMP_WORDS[1]} == "git" && ${prev} == "sync" ]]; then
    # Complete with sync flags, directories and repos.txt files
    local sync_flags="--file --dry-run --default-strategy --protocol --verbose --force --help"
    COMPREPLY=($(compgen -W "${sync_flags}" -- "${cur}"))
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
  elif [[ ${COMP_WORDS[1]} == "git" && ${COMP_WORDS[2]} == "sync" ]]; then
    # Handle git sync subcommand arguments
    case "${prev}" in
      --file)
        # Complete with files
        COMPREPLY=($(compgen -f -- "${cur}"))
        ;;
      --default-strategy)
        # Complete with strategy options
        COMPREPLY=($(compgen -W "shared local" -- "${cur}"))
        ;;
      --protocol)
        # Complete with protocol options
        COMPREPLY=($(compgen -W "git https" -- "${cur}"))
        ;;
      *)
        # Complete with directories, files, and remaining flags
        local sync_flags="--file --dry-run --default-strategy --protocol --verbose --force --help"
        COMPREPLY=($(compgen -W "${sync_flags}" -- "${cur}"))
        local dirs=($(compgen -d -- "${cur}" 2>/dev/null))
        COMPREPLY+=("${dirs[@]}")
        local txtfiles=($(compgen -f -X '!*.txt' -- "${cur}" 2>/dev/null))
        COMPREPLY+=("${txtfiles[@]}")
        ;;
    esac
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
