_mt_stow() {
  # Check for required stow command
  command -v stow &>/dev/null || {
    echo "Error: 'stow' command is required but not found." >&2
    echo "Please install GNU Stow (e.g. 'apt install stow' or 'brew install stow')" >&2
    exit 1
  }

  # Use MT_PKG_DIR from environment or set default
  : "${MT_PKG_DIR:=${HOME}/.metool}"

  if [[ $# -lt 1 ]]; then
    echo "Usage: mt stow [STOW_OPTIONS] DIRECTORY..." >&2
    exit 1
  fi

  # Get stow options and package paths
  declare -a stow_opts=()
  declare -a pkg_paths=()
  declare -a skipped_files=()
  local mt_verbose=false
  local found_valid_path=false

  # Parse arguments into options and paths
  for arg in "$@"; do
    if [[ "$arg" == "--mt-verbose" ]]; then
      mt_verbose=true
    elif [[ "$arg" == -* ]]; then
      stow_opts+=("$arg")
    elif [[ -d "$arg" ]]; then
      pkg_paths+=("$(realpath "$arg")")
      found_valid_path=true
    elif [[ -e "$arg" ]]; then
      # File exists but is not a directory - track it
      skipped_files+=("$arg")
    elif [[ -L "$arg" ]]; then
      # It's a symlink but target doesn't exist (broken symlink)
      _mt_error "Broken symlink: $arg -> $(readlink "$arg")"
    else
      _mt_error "Path not found: $arg"
    fi
  done
  
  # If we have skipped files, check if they look like explicit arguments
  if [[ ${#skipped_files[@]} -gt 0 ]]; then
    # If we have many arguments (likely from wildcard) and some are directories, 
    # then the files were probably included by wildcard expansion
    if [[ $# -gt 3 ]] && [[ ${#pkg_paths[@]} -gt 0 ]]; then
      # Silently skip - this looks like wildcard expansion
      :
    else
      # Few arguments or no directories found - likely explicit file arguments
      for file in "${skipped_files[@]}"; do
        _mt_error "Not a directory: $file"
      done
    fi
  fi
  
  # Check if we found any valid directories to process
  if [[ "${#pkg_paths[@]}" -eq 0 ]]; then
    if [[ "${#stow_opts[@]}" -eq 0 ]] || ! $found_valid_path; then
      _mt_error "No valid directories to install. Please provide at least one existing directory."
      return 1
    fi
  fi

  # Track if any errors occurred
  local had_errors=false
  local pkg_results=()

  # Process each directory
  for pkg_path in "${pkg_paths[@]}"; do
    pkg_name="$(basename "$pkg_path")"
    local pkg_status=""
    local pkg_had_error=false

    # Handle bin/
    if [[ -d "${pkg_path}/bin" ]]; then
      command mkdir -p "${MT_PKG_DIR}/bin"
      if command stow ${stow_opts[@]+"${stow_opts[@]}"} --dir="${pkg_path}" --target="${MT_PKG_DIR}/bin" bin &>/tmp/mt_stow_output; then
        pkg_status+="${MT_COLOR_INFO}bin${MT_COLOR_RESET} "
      else
        pkg_status+="${MT_COLOR_ERROR}bin${MT_COLOR_RESET} "
        pkg_had_error=true
        had_errors=true
        command cat /tmp/mt_stow_output | sed "s/^/[${pkg_name}:bin] /" >&2
      fi
    fi

    # Handle config/
    if [[ -d "${pkg_path}/config" ]]; then
      # First, create an intermediate directory for configs
      command mkdir -p "${MT_PKG_DIR}/config/${pkg_name}"

      # Stow from package to metool config dir
      if command stow ${stow_opts[@]+"${stow_opts[@]}"} --dir="${pkg_path}" --target="${MT_PKG_DIR}/config/${pkg_name}" config &>/tmp/mt_stow_output; then
        # Now stow from metool config dir to HOME
        if command stow ${stow_opts[@]+"${stow_opts[@]}"} --dir="${MT_PKG_DIR}/config" --target="${HOME}" --dotfiles "${pkg_name}" &>/tmp/mt_stow_output_2; then
          pkg_status+="${MT_COLOR_INFO}config${MT_COLOR_RESET} "
        else
          pkg_status+="${MT_COLOR_ERROR}config${MT_COLOR_RESET} "
          pkg_had_error=true
          had_errors=true
          
          # Enhanced conflict resolution
          command cat /tmp/mt_stow_output_2 | sed "s/^/[${pkg_name}:config->home] /" >&2
          
          # Extract conflict files from stow output
          local conflict_files=()
          while read -r line; do
            if [[ "$line" =~ \*\ existing\ target\ is\ not\ owned\ by\ stow:\ (.+) ]]; then
              conflict_files+=("${BASH_REMATCH[1]}")
            fi
          done < /tmp/mt_stow_output_2
          
          # Handle each conflict file
          if [[ ${#conflict_files[@]} -gt 0 ]]; then
            echo -e "\n${MT_COLOR_WARNING}Conflicts detected during installation of ${pkg_name}:${MT_COLOR_RESET}"
            
            for conflict in "${conflict_files[@]}"; do
              local conflict_path="${HOME}/${conflict}"
              
              # Check if the file is a symlink
              if [[ -L "${conflict_path}" ]]; then
                local link_target=$(readlink -f "${conflict_path}")
                local link_status="valid"
                
                # Check if it's a broken symlink
                if [[ ! -e "${conflict_path}" ]]; then
                  link_status="broken"
                fi
                
                echo -e "  ${MT_COLOR_WARNING}→ ${conflict} is a ${link_status} symlink pointing to:${MT_COLOR_RESET}"
                echo -e "    ${link_target}"
                
                # Offer to fix broken symlinks automatically
                if [[ "$link_status" == "broken" ]]; then
                  echo -e "  ${MT_COLOR_WARNING}This is a broken symlink and could be safely removed.${MT_COLOR_RESET}"
                fi
              else
                echo -e "  ${MT_COLOR_WARNING}→ ${conflict} is a regular file or directory${MT_COLOR_RESET}"
              fi
              
              # Offer to remove the conflicting item
              # Source prompt functions if needed
              if ! type -t _mt_confirm >/dev/null; then
                source "$(dirname "${BASH_SOURCE[0]}")/prompt.sh"
              fi
              
              _mt_confirm "  Remove this conflicting item and try again?"
              if [[ $? -eq 0 ]]; then
                echo -e "  ${MT_COLOR_INFO}→ Removing ${conflict_path}...${MT_COLOR_RESET}"
                command rm -f "${conflict_path}"
                
                # Try stowing again after resolving conflict
                if command stow ${stow_opts[@]+"${stow_opts[@]}"} --dir="${MT_PKG_DIR}/config" --target="${HOME}" --dotfiles "${pkg_name}" &>/tmp/mt_stow_retry; then
                  echo -e "  ${MT_COLOR_INFO}→ Conflict resolved successfully!${MT_COLOR_RESET}"
                  # Update status to success
                  pkg_status=${pkg_status/${MT_COLOR_ERROR}config${MT_COLOR_RESET}/${MT_COLOR_INFO}config${MT_COLOR_RESET}}
                  pkg_had_error=false
                  had_errors=false  # This might need to be set at a higher level based on other errors
                else
                  echo -e "  ${MT_COLOR_ERROR}→ Still having issues after conflict resolution:${MT_COLOR_RESET}"
                  command cat /tmp/mt_stow_retry | sed "s/^/    /" >&2
                fi
              else
                echo -e "  ${MT_COLOR_WARNING}→ Skipping conflict resolution for this item${MT_COLOR_RESET}"
              fi
            done
          fi
        fi
      else
        pkg_status+="${MT_COLOR_ERROR}config${MT_COLOR_RESET} "
        pkg_had_error=true
        had_errors=true
        command cat /tmp/mt_stow_output | sed "s/^/[${pkg_name}:config->metool] /" >&2
      fi
    fi

    # Handle shell/
    if [[ -d "${pkg_path}/shell" ]]; then
      command mkdir -p "${MT_PKG_DIR}/shell/${pkg_name}"
      if command stow ${stow_opts[@]+"${stow_opts[@]}"} --dir="${pkg_path}" --target="${MT_PKG_DIR}/shell/${pkg_name}" shell &>/tmp/mt_stow_output; then
        pkg_status+="${MT_COLOR_INFO}shell${MT_COLOR_RESET} "
      else
        pkg_status+="${MT_COLOR_ERROR}shell${MT_COLOR_RESET} "
        pkg_had_error=true
        had_errors=true
        command cat /tmp/mt_stow_output | sed "s/^/[${pkg_name}:shell] /" >&2
      fi
    fi

    # Only show detailed output for packages with errors or if verbose mode is enabled
    if $pkg_had_error || $mt_verbose; then
      printf "${pkg_name}: ${pkg_status}\n"
    fi

    # Store result for summary
    if $pkg_had_error; then
      pkg_results+=("\033[0;31m${pkg_name}\033[0m")
    else
      pkg_results+=("\033[0;34m${pkg_name}\033[0m")
    fi
  done

  # Print summary
  if $had_errors; then
    printf "\nStow completed (with errors) in: ${pkg_results[*]}\n"
    printf "Use 'mt stow --mt-verbose' to see all package details\n"
  elif $mt_verbose; then
    printf "\nStow completed successfully for: ${pkg_results[*]}\n"
  else
    printf "Stow completed successfully for: ${pkg_results[*]}\n"
  fi

  # Clean up temp file
  command rm -f /tmp/mt_stow_output

  # If metool itself was installed and no errors occurred, offer to update .bashrc
  for pkg_path in "${pkg_paths[@]}"; do
    pkg_name="$(basename "$pkg_path")"
    if [[ "$pkg_name" == "metool" ]] && ! $had_errors; then
      _mt_update_bashrc
      break
    fi
  done

  # Invalidate cache after installation
  _mt_invalidate_cache
}
