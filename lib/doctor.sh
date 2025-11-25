#!/usr/bin/env bash
# doctor.sh - System health diagnostics for metool (MT-12)

# ==============================================================================
# Global State for Doctor
# ==============================================================================

declare -g DOCTOR_ERRORS=0
declare -g DOCTOR_WARNINGS=0
declare -g DOCTOR_FIX_MODE=false
declare -g DOCTOR_YES_MODE=false
declare -g DOCTOR_VERBOSE=false
declare -g DOCTOR_JSON=false

# Arrays to collect issues for summary
declare -ga DOCTOR_ERROR_MESSAGES=()
declare -ga DOCTOR_WARNING_MESSAGES=()
declare -ga DOCTOR_RECOMMENDATIONS=()

# ==============================================================================
# Output Helpers
# ==============================================================================

_mt_doctor_header() {
  local title="$1"
  if [[ "$DOCTOR_JSON" != "true" ]]; then
    echo ""
    echo -e "${MT_COLOR_BOLD}${title}${MT_COLOR_RESET}"
  fi
}

_mt_doctor_ok() {
  local message="$1"
  if [[ "$DOCTOR_JSON" != "true" ]]; then
    echo -e "  ${MT_COLOR_GREEN}✓${MT_COLOR_RESET} ${message}"
  fi
}

_mt_doctor_error() {
  local message="$1"
  local details="${2:-}"
  local fix="${3:-}"

  ((DOCTOR_ERRORS++))

  if [[ "$DOCTOR_JSON" != "true" ]]; then
    echo -e "  ${MT_COLOR_RED}✗${MT_COLOR_RESET} ${message}"
    if [[ -n "$details" ]]; then
      echo -e "    ${MT_COLOR_DIM}${details}${MT_COLOR_RESET}"
    fi
    if [[ -n "$fix" ]]; then
      echo -e "    ${MT_COLOR_CYAN}Fix: ${fix}${MT_COLOR_RESET}"
    fi
  fi

  DOCTOR_ERROR_MESSAGES+=("$message")
  if [[ -n "$fix" ]]; then
    DOCTOR_RECOMMENDATIONS+=("$fix")
  fi
}

_mt_doctor_warning() {
  local message="$1"
  local details="${2:-}"
  local recommendation="${3:-}"

  ((DOCTOR_WARNINGS++))

  if [[ "$DOCTOR_JSON" != "true" ]]; then
    echo -e "  ${MT_COLOR_YELLOW}⚠${MT_COLOR_RESET} ${message}"
    if [[ -n "$details" ]]; then
      echo -e "    ${MT_COLOR_DIM}${details}${MT_COLOR_RESET}"
    fi
    if [[ -n "$recommendation" ]]; then
      echo -e "    ${MT_COLOR_CYAN}Recommendation: ${recommendation}${MT_COLOR_RESET}"
    fi
  fi

  DOCTOR_WARNING_MESSAGES+=("$message")
  if [[ -n "$recommendation" ]]; then
    DOCTOR_RECOMMENDATIONS+=("$recommendation")
  fi
}

_mt_doctor_info() {
  local message="$1"
  if [[ "$DOCTOR_JSON" != "true" ]] && [[ "$DOCTOR_VERBOSE" == "true" ]]; then
    echo -e "  ${MT_COLOR_DIM}${message}${MT_COLOR_RESET}"
  fi
}

# ==============================================================================
# Root Cause Analysis
# ==============================================================================

# Determine why a symlink is broken
_mt_doctor_analyze_broken_symlink() {
  local link_path="$1"
  local target
  target=$(readlink "$link_path" 2>/dev/null)

  if [[ -z "$target" ]]; then
    echo "Cannot read symlink target"
    return
  fi

  # Check for Claude Code snapshot path
  if [[ "$target" =~ \.claude/settings/snapshots/ ]] || [[ "$target" =~ \.claude/settings/local/ ]]; then
    echo "Target was a Claude Code snapshot (temporary directory that was cleaned up)"
    return
  fi

  # Check if target looks like a module path that was removed
  if [[ "$target" =~ /modules/([^/]+)/ ]]; then
    local module_name="${BASH_REMATCH[1]}"
    if [[ ! -L "${MT_MODULES_DIR}/${module_name}" ]]; then
      echo "Module '${module_name}' is not in working set"
      return
    fi
    if [[ ! -d "$(readlink -f "${MT_MODULES_DIR}/${module_name}" 2>/dev/null)" ]]; then
      echo "Module '${module_name}' symlink is also broken"
      return
    fi
  fi

  # Check if parent directory exists
  local parent_dir
  parent_dir=$(dirname "$target")
  if [[ ! -d "$parent_dir" ]]; then
    echo "Parent directory does not exist: ${parent_dir/$HOME/~}"
    return
  fi

  # Generic case
  echo "Target does not exist: ${target/$HOME/~}"
}

# ==============================================================================
# Dependencies Check
# ==============================================================================

_mt_doctor_deps() {
  _mt_doctor_header "Dependencies:"

  local has_errors=false

  # Check stow
  if command -v stow &>/dev/null; then
    local stow_version
    stow_version=$(stow --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [[ -n "$stow_version" ]]; then
      local major minor
      major=$(echo "$stow_version" | cut -d. -f1)
      minor=$(echo "$stow_version" | cut -d. -f2)
      if [[ "$major" -gt 2 ]] || ([[ "$major" -eq 2 ]] && [[ "$minor" -ge 4 ]]); then
        _mt_doctor_ok "stow ${stow_version}"
      else
        _mt_doctor_warning "stow ${stow_version} (2.4.0+ recommended for full functionality)" \
          "Some features may not work correctly" \
          "brew upgrade stow"
      fi
    else
      _mt_doctor_warning "stow (version unknown)" "" ""
    fi
  else
    _mt_doctor_error "stow not found" "" "brew install stow"
    has_errors=true
  fi

  # Check realpath
  if command -v realpath &>/dev/null; then
    _mt_doctor_ok "realpath (coreutils)"
  else
    _mt_doctor_error "realpath not found" "" "brew install coreutils"
    has_errors=true
  fi

  # Check bash version
  if [[ -n "${METOOL_BASH_VERSION:-}" ]]; then
    _mt_doctor_ok "bash ${METOOL_BASH_VERSION}"
  else
    local bash_version
    bash_version=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major=${bash_version%%.*}
    if [[ "$major" -ge 4 ]]; then
      _mt_doctor_ok "bash ${bash_version}"
    else
      _mt_doctor_error "bash ${bash_version} (need 4.0+)" "" "brew install bash"
      has_errors=true
    fi
  fi

  # Check symlinks command (optional - helpful for finding broken symlinks)
  if command -v symlinks &>/dev/null; then
    local symlinks_version
    symlinks_version=$(symlinks -v 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [[ -n "$symlinks_version" ]]; then
      _mt_doctor_ok "symlinks ${symlinks_version}"
    else
      _mt_doctor_ok "symlinks"
    fi
  else
    _mt_doctor_info "symlinks not installed (optional - install with: brew install symlinks)"
  fi

  $has_errors && return 1
  return 0
}

# ==============================================================================
# Working Set Integrity
# ==============================================================================

_mt_doctor_working_set() {
  _mt_doctor_header "Working Sets:"

  local modules_total=0
  local modules_valid=0
  local packages_total=0
  local packages_valid=0

  # Check modules
  if [[ -d "${MT_MODULES_DIR}" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue
      ((modules_total++))

      local target
      target=$(readlink -f "$link" 2>/dev/null)
      local link_name
      link_name=$(basename "$link")

      if [[ -n "$target" ]] && [[ -d "$target" ]]; then
        ((modules_valid++))
        _mt_doctor_info "Module: ${link_name} -> ${target/$HOME/~}"
      else
        local raw_target
        raw_target=$(readlink "$link")
        local root_cause
        root_cause=$(_mt_doctor_analyze_broken_symlink "$link")
        _mt_doctor_error "Module symlink broken: ${link_name}" \
          "-> ${raw_target/$HOME/~}" \
          "mt module remove ${link_name}"
      fi
    done < <(find "${MT_MODULES_DIR}" -maxdepth 1 -type l 2>/dev/null)
  fi

  if [[ $modules_total -eq 0 ]]; then
    _mt_doctor_info "No modules in working set"
  elif [[ $modules_valid -eq $modules_total ]]; then
    _mt_doctor_ok "Modules: ${modules_valid}/${modules_total} valid symlinks"
  else
    echo -e "  ${MT_COLOR_RED}✗${MT_COLOR_RESET} Modules: ${modules_valid}/${modules_total} valid symlinks"
  fi

  # Check packages
  if [[ -d "${MT_PACKAGES_DIR}" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue
      ((packages_total++))

      local target
      target=$(readlink -f "$link" 2>/dev/null)
      local link_name
      link_name=$(basename "$link")

      if [[ -n "$target" ]] && [[ -d "$target" ]]; then
        ((packages_valid++))
        _mt_doctor_info "Package: ${link_name} -> ${target/$HOME/~}"
      else
        local raw_target
        raw_target=$(readlink "$link")
        local root_cause
        root_cause=$(_mt_doctor_analyze_broken_symlink "$link")
        _mt_doctor_error "Package symlink broken: ${link_name}" \
          "-> ${raw_target/$HOME/~}\nRoot cause: ${root_cause}" \
          "mt package remove ${link_name}"
      fi
    done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null)
  fi

  if [[ $packages_total -eq 0 ]]; then
    _mt_doctor_info "No packages in working set"
  elif [[ $packages_valid -eq $packages_total ]]; then
    _mt_doctor_ok "Packages: ${packages_valid}/${packages_total} valid symlinks"
  else
    echo -e "  ${MT_COLOR_RED}✗${MT_COLOR_RESET} Packages: ${packages_valid}/${packages_total} valid symlinks"
  fi
}

# ==============================================================================
# Skills Symlinks Check
# ==============================================================================

_mt_doctor_skills() {
  _mt_doctor_header "Skills:"

  local metool_skills_total=0
  local metool_skills_valid=0
  local claude_skills_total=0
  local claude_skills_valid=0

  # Check ~/.metool/skills/ (Stage 1)
  local skills_dir="${MT_PKG_DIR}/skills"
  if [[ -d "$skills_dir" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue
      ((metool_skills_total++))

      local target
      target=$(readlink -f "$link" 2>/dev/null)
      local link_name
      link_name=$(basename "$link")

      if [[ -n "$target" ]] && [[ -d "$target" ]]; then
        ((metool_skills_valid++))
        _mt_doctor_info "Metool skill: ${link_name} -> ${target/$HOME/~}"
      else
        local raw_target
        raw_target=$(readlink "$link")
        local root_cause
        root_cause=$(_mt_doctor_analyze_broken_symlink "$link")
        _mt_doctor_error "Metool skill symlink broken: ${link_name}" \
          "-> ${raw_target/$HOME/~}\nRoot cause: ${root_cause}" \
          "rm '${link}' or mt package install ${link_name}"
      fi
    done < <(find "$skills_dir" -maxdepth 1 -type l 2>/dev/null)
  fi

  if [[ $metool_skills_total -eq 0 ]]; then
    _mt_doctor_info "No skills in ~/.metool/skills/"
  elif [[ $metool_skills_valid -eq $metool_skills_total ]]; then
    _mt_doctor_ok "~/.metool/skills: ${metool_skills_valid}/${metool_skills_total} valid symlinks"
  else
    echo -e "  ${MT_COLOR_RED}✗${MT_COLOR_RESET} ~/.metool/skills: ${metool_skills_valid}/${metool_skills_total} valid symlinks"
  fi

  # Check ~/.claude/skills/ (Stage 2)
  local claude_skills_dir="${HOME}/.claude/skills"
  if [[ -d "$claude_skills_dir" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue
      ((claude_skills_total++))

      local link_name
      link_name=$(basename "$link")

      # First check if the immediate target exists
      local immediate_target
      immediate_target=$(readlink "$link")

      # Then check the final target
      local final_target
      final_target=$(readlink -f "$link" 2>/dev/null)

      if [[ -n "$final_target" ]] && [[ -d "$final_target" ]]; then
        ((claude_skills_valid++))
        _mt_doctor_info "Claude skill: ${link_name} -> ${final_target/$HOME/~}"
      else
        local root_cause
        root_cause=$(_mt_doctor_analyze_broken_symlink "$link")

        # Check if it's a two-stage symlink issue
        local stage_info=""
        if [[ "$immediate_target" =~ \.metool/skills/ ]]; then
          local metool_skill_link="${MT_PKG_DIR}/skills/${link_name}"
          if [[ -L "$metool_skill_link" ]]; then
            local metool_target
            metool_target=$(readlink "$metool_skill_link")
            stage_info=" -> ${immediate_target/$HOME/~} -> ${metool_target/$HOME/~}"
          fi
        fi

        _mt_doctor_error "Claude skill symlink broken: ${link_name}" \
          "${stage_info}\nRoot cause: ${root_cause}" \
          "mt package install ${link_name}"
      fi
    done < <(find "$claude_skills_dir" -maxdepth 1 -type l 2>/dev/null)
  fi

  if [[ $claude_skills_total -eq 0 ]]; then
    _mt_doctor_info "No skills in ~/.claude/skills/"
  elif [[ $claude_skills_valid -eq $claude_skills_total ]]; then
    _mt_doctor_ok "~/.claude/skills: ${claude_skills_valid}/${claude_skills_total} valid symlinks"
  else
    echo -e "  ${MT_COLOR_RED}✗${MT_COLOR_RESET} ~/.claude/skills: ${claude_skills_valid}/${claude_skills_total} valid symlinks"
  fi

  # Check for packages with SKILL.md that aren't linked
  if [[ "$DOCTOR_VERBOSE" == "true" ]] && [[ -d "${MT_PACKAGES_DIR}" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue
      local pkg_path
      pkg_path=$(readlink -f "$link" 2>/dev/null)
      [[ -d "$pkg_path" ]] || continue

      local pkg_name
      pkg_name=$(basename "$link")

      if [[ -f "${pkg_path}/SKILL.md" ]]; then
        if [[ ! -L "${skills_dir}/${pkg_name}" ]]; then
          _mt_doctor_warning "Package has SKILL.md but not linked: ${pkg_name}" \
            "" \
            "mt package install ${pkg_name}"
        fi
      fi
    done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null)
  fi
}

# ==============================================================================
# Installation Status
# ==============================================================================

_mt_doctor_installed() {
  _mt_doctor_header "Installation Status:"

  local in_working_set_not_installed=0
  local orphaned_symlinks=0

  # Check packages in working set that aren't installed
  if [[ -d "${MT_PACKAGES_DIR}" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue

      local pkg_name
      pkg_name=$(basename "$link")
      local pkg_path
      pkg_path=$(readlink -f "$link" 2>/dev/null)

      [[ -d "$pkg_path" ]] || continue

      # Check if package has installable components
      local has_components=false
      for component in bin shell config; do
        if [[ -d "${pkg_path}/${component}" ]]; then
          has_components=true
          break
        fi
      done

      if $has_components; then
        # Check if installed using working-set helper
        if ! _mt_package_is_installed "$pkg_name" 2>/dev/null; then
          ((in_working_set_not_installed++))
          _mt_doctor_warning "Package in working set but not installed: ${pkg_name}" \
            "" \
            "mt package install ${pkg_name}"
        fi
      fi
    done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null)
  fi

  # Check for orphaned symlinks in bin/, shell/, config/
  for component_dir in bin shell config; do
    local stow_dir="${MT_PKG_DIR}/${component_dir}"
    [[ -d "$stow_dir" ]] || continue

    while IFS= read -r link; do
      [[ -L "$link" ]] || continue

      local target
      target=$(readlink -f "$link" 2>/dev/null)

      if [[ -z "$target" ]] || [[ ! -e "$target" ]]; then
        ((orphaned_symlinks++))
        local raw_target
        raw_target=$(readlink "$link")
        local root_cause
        root_cause=$(_mt_doctor_analyze_broken_symlink "$link")
        _mt_doctor_error "Orphaned symlink in ${component_dir}/: $(basename "$link")" \
          "-> ${raw_target/$HOME/~}\nRoot cause: ${root_cause}" \
          "rm '${link}'"
      fi
    done < <(find "$stow_dir" -type l 2>/dev/null)
  done

  if [[ $in_working_set_not_installed -eq 0 ]] && [[ $orphaned_symlinks -eq 0 ]]; then
    _mt_doctor_ok "All packages properly installed"
  fi
}

# ==============================================================================
# Stow Conflict Detection
# ==============================================================================

_mt_doctor_conflicts() {
  _mt_doctor_header "Conflict Detection:"

  local conflicts_found=0

  # Build a map of all files that would be installed
  declare -A file_sources

  if [[ -d "${MT_PACKAGES_DIR}" ]]; then
    while IFS= read -r link; do
      [[ -L "$link" ]] || continue

      local pkg_name
      pkg_name=$(basename "$link")
      local pkg_path
      pkg_path=$(readlink -f "$link" 2>/dev/null)

      [[ -d "$pkg_path" ]] || continue

      for component in bin shell config; do
        local component_path="${pkg_path}/${component}"
        [[ -d "$component_path" ]] || continue

        while IFS= read -r file; do
          [[ -f "$file" ]] || [[ -L "$file" ]] || continue

          # Get relative path within component
          local rel_path="${file#${component_path}/}"
          local key="${component}/${rel_path}"

          if [[ -n "${file_sources[$key]:-}" ]]; then
            ((conflicts_found++))
            _mt_doctor_warning "Potential stow conflict: ${key}" \
              "Provided by: ${file_sources[$key]} and ${pkg_name}" \
              "Resolve by removing one package or renaming the file"
          else
            file_sources["$key"]="$pkg_name"
          fi
        done < <(find "$component_path" -type f -o -type l 2>/dev/null)
      done
    done < <(find "${MT_PACKAGES_DIR}" -maxdepth 1 -type l 2>/dev/null)
  fi

  if [[ $conflicts_found -eq 0 ]]; then
    _mt_doctor_ok "No stow conflicts detected"
  fi
}

# ==============================================================================
# Fix Mode
# ==============================================================================

_mt_doctor_fix_broken_symlink() {
  local link_path="$1"
  local link_name
  link_name=$(basename "$link_path")

  if [[ "$DOCTOR_YES_MODE" == "true" ]]; then
    rm "$link_path"
    echo "  Removed: ${link_path/$HOME/~}"
    return 0
  fi

  echo ""
  echo -e "Remove broken symlink: ${MT_COLOR_CYAN}${link_path/$HOME/~}${MT_COLOR_RESET}?"
  read -p "  [y/N] " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm "$link_path"
    echo "  Removed: ${link_path/$HOME/~}"
    return 0
  fi

  return 1
}

# ==============================================================================
# Summary
# ==============================================================================

_mt_doctor_summary() {
  if [[ "$DOCTOR_JSON" == "true" ]]; then
    _mt_doctor_json_output
    return
  fi

  echo ""
  echo -e "${MT_COLOR_BOLD}Summary${MT_COLOR_RESET}"
  echo "======="

  if [[ $DOCTOR_ERRORS -eq 0 ]] && [[ $DOCTOR_WARNINGS -eq 0 ]]; then
    echo -e "${MT_COLOR_GREEN}✓ All checks passed${MT_COLOR_RESET}"
  else
    if [[ $DOCTOR_ERRORS -gt 0 ]]; then
      echo -e "${MT_COLOR_RED}Errors: ${DOCTOR_ERRORS}${MT_COLOR_RESET}"
    fi
    if [[ $DOCTOR_WARNINGS -gt 0 ]]; then
      echo -e "${MT_COLOR_YELLOW}Warnings: ${DOCTOR_WARNINGS}${MT_COLOR_RESET}"
    fi

    if [[ ${#DOCTOR_RECOMMENDATIONS[@]} -gt 0 ]] && [[ "$DOCTOR_FIX_MODE" != "true" ]]; then
      echo ""
      echo -e "${MT_COLOR_BOLD}Recommendations:${MT_COLOR_RESET}"
      local i=1
      local -A seen_recommendations
      for rec in "${DOCTOR_RECOMMENDATIONS[@]}"; do
        if [[ -z "${seen_recommendations[$rec]:-}" ]]; then
          echo "  ${i}. ${rec}"
          seen_recommendations["$rec"]=1
          ((i++))
        fi
      done
      echo ""
      echo "Run 'mt doctor --fix' to auto-repair issues"
    fi
  fi

  echo ""
  if [[ $DOCTOR_ERRORS -gt 0 ]]; then
    echo -e "Health Status: ${MT_COLOR_RED}ERRORS${MT_COLOR_RESET} (${DOCTOR_ERRORS} error(s), ${DOCTOR_WARNINGS} warning(s))"
    return 1
  elif [[ $DOCTOR_WARNINGS -gt 0 ]]; then
    echo -e "Health Status: ${MT_COLOR_YELLOW}WARNINGS${MT_COLOR_RESET} (${DOCTOR_WARNINGS} warning(s))"
    return 0
  else
    echo -e "Health Status: ${MT_COLOR_GREEN}OK${MT_COLOR_RESET}"
    return 0
  fi
}

_mt_doctor_json_output() {
  echo "{"
  echo "  \"errors\": ${DOCTOR_ERRORS},"
  echo "  \"warnings\": ${DOCTOR_WARNINGS},"
  echo "  \"status\": \"$(
    if [[ $DOCTOR_ERRORS -gt 0 ]]; then
      echo "errors"
    elif [[ $DOCTOR_WARNINGS -gt 0 ]]; then
      echo "warnings"
    else
      echo "ok"
    fi
  )\","
  echo "  \"error_messages\": ["
  local first=true
  for msg in "${DOCTOR_ERROR_MESSAGES[@]}"; do
    $first || echo ","
    printf "    \"%s\"" "${msg//\"/\\\"}"
    first=false
  done
  echo ""
  echo "  ],"
  echo "  \"warning_messages\": ["
  first=true
  for msg in "${DOCTOR_WARNING_MESSAGES[@]}"; do
    $first || echo ","
    printf "    \"%s\"" "${msg//\"/\\\"}"
    first=false
  done
  echo ""
  echo "  ],"
  echo "  \"recommendations\": ["
  first=true
  local -A seen
  for rec in "${DOCTOR_RECOMMENDATIONS[@]}"; do
    if [[ -z "${seen[$rec]:-}" ]]; then
      $first || echo ","
      printf "    \"%s\"" "${rec//\"/\\\"}"
      seen["$rec"]=1
      first=false
    fi
  done
  echo ""
  echo "  ]"
  echo "}"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================

_mt_doctor() {
  # Reset state
  DOCTOR_ERRORS=0
  DOCTOR_WARNINGS=0
  DOCTOR_FIX_MODE=false
  DOCTOR_YES_MODE=false
  DOCTOR_VERBOSE=false
  DOCTOR_JSON=false
  DOCTOR_ERROR_MESSAGES=()
  DOCTOR_WARNING_MESSAGES=()
  DOCTOR_RECOMMENDATIONS=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix)
        DOCTOR_FIX_MODE=true
        shift
        ;;
      --yes|-y)
        DOCTOR_YES_MODE=true
        shift
        ;;
      --verbose|-v)
        DOCTOR_VERBOSE=true
        shift
        ;;
      --json)
        DOCTOR_JSON=true
        shift
        ;;
      -h|--help)
        cat << 'EOF'
Usage: mt doctor [OPTIONS]

Run system health diagnostics for metool.

OPTIONS:
    --fix           Automatically repair common issues (with confirmation)
    --yes, -y       Auto-confirm repairs (use with --fix)
    --verbose, -v   Show detailed information including successful checks
    --json          Output in JSON format for scripting
    -h, --help      Show this help message

EXAMPLES:
    mt doctor              # Run all health checks
    mt doctor --verbose    # Show all details including passing checks
    mt doctor --fix        # Interactively fix issues
    mt doctor --fix --yes  # Auto-fix all issues without prompting
    mt doctor --json       # Output results as JSON

CHECKS PERFORMED:
    - Dependencies (stow, realpath, bash, symlinks)
    - Working set integrity (modules/ and packages/ symlinks)
    - Skill symlinks (two-stage Claude Code integration)
    - Installation status (packages installed vs in working set)
    - Stow conflict detection (overlapping files)
EOF
        return 0
        ;;
      *)
        _mt_error "Unknown option: $1"
        echo "Run 'mt doctor --help' for usage information."
        return 1
        ;;
    esac
  done

  if [[ "$DOCTOR_JSON" != "true" ]]; then
    echo -e "${MT_COLOR_BOLD}Metool Health Check${MT_COLOR_RESET}"
    echo "==================="
  fi

  # Run all checks
  _mt_doctor_deps
  _mt_doctor_working_set
  _mt_doctor_skills
  _mt_doctor_installed
  _mt_doctor_conflicts

  # Show summary
  _mt_doctor_summary
}
