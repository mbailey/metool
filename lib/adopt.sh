#!/usr/bin/env bash
# Functions for adopting user-side dotfile drift back into a package source.
# Pinned to its own file (see MT-58 design) to avoid bloating lib/stow.sh.

# Replicate GNU stow's `--dotfiles` mapping for a single relative path:
# any path component starting with `dot-` has the prefix replaced with `.`.
# (e.g. `dot-config/nvim/init.lua` -> `.config/nvim/init.lua`,
#       `dotrc` -> `dotrc` (untouched -- prefix is `dot`, not `dot-`)).
_mt_adopt_dotfiles_transform() {
  local relpath="$1"
  local out=""
  local component
  local IFS='/'
  # shellcheck disable=SC2206
  local -a parts=( $relpath )
  for component in "${parts[@]}"; do
    if [[ "$component" == dot-* ]]; then
      component=".${component#dot-}"
    fi
    if [[ -z "$out" ]]; then
      out="$component"
    else
      out="${out}/${component}"
    fi
  done
  printf '%s' "$out"
}

# _mt_adopt_plan <package_path> <package_name>
#
# Pure function. Walks <package_path>/config/ and emits a tab-separated plan
# describing what `mt package install --adopt` would do to each destination.
# One line per (status, source, dest) triple, where status is one of:
#
#   missing              dest doesn't exist (or is a broken symlink to nothing
#                        we can resolve; treated as missing for plan purposes)
#   regular_file         dest is a non-symlink file with content != source
#   symlink_correct      dest is a symlink that resolves to source
#   symlink_other        dest is a symlink that resolves elsewhere (or dest is
#                        a directory or other unexpected type -- treat as
#                        "don't touch" so apply leaves it alone)
#   identical_to_source  dest is a non-symlink file byte-equal to source
#
# Output format: "<status>\t<source>\t<dest>\n" (one line per pair).
# No filesystem mutations.
_mt_adopt_plan() {
  local package_path="$1"
  local package_name="$2"

  if [[ -z "$package_path" ]] || [[ -z "$package_name" ]]; then
    _mt_error "Usage: _mt_adopt_plan <package_path> <package_name>"
    return 1
  fi

  local config_dir="${package_path}/config"
  [[ -d "$config_dir" ]] || return 0

  local source_real
  local source dest relpath transformed status link_real
  while IFS= read -r -d '' source; do
    relpath="${source#${config_dir}/}"
    transformed=$(_mt_adopt_dotfiles_transform "$relpath")
    dest="${HOME}/${transformed}"

    if [[ -L "$dest" ]]; then
      link_real=$(readlink -f "$dest" 2>/dev/null)
      source_real=$(readlink -f "$source" 2>/dev/null)
      if [[ -n "$link_real" && "$link_real" == "$source_real" ]]; then
        status="symlink_correct"
      else
        status="symlink_other"
      fi
    elif [[ ! -e "$dest" ]]; then
      status="missing"
    elif [[ -f "$dest" ]]; then
      if cmp -s "$dest" "$source"; then
        status="identical_to_source"
      else
        status="regular_file"
      fi
    else
      # Directory or other non-file, non-symlink type -- skip-equivalent.
      status="symlink_other"
    fi

    printf '%s\t%s\t%s\n' "$status" "$source" "$dest"
  done < <(find "$config_dir" -type f -print0 2>/dev/null)
}

# _mt_adopt_check_clean <package_path> <force> <relpath...>
#
# Safety guard for `mt package install --adopt`: refuse to overwrite files in
# the package source if any of those files have uncommitted changes in the
# package's git working tree. Caller passes the would-be-overwritten paths as
# repo-relative paths (e.g. `config/dot-gitconfig`).
#
# - <force>: when "true", skip the check entirely and return clean.
# - If <package_path> is not inside a git working tree, print a warning and
#   treat as clean (no review trail, but proceed).
# - Otherwise, run `git -C <package_path> status --porcelain -- <relpaths>`.
#   Any output means at least one path is dirty -- print the listing and
#   return non-zero so the caller aborts before any filesystem mutation.
#
# Returns 0 if clean (or skipped), 1 if dirty.
_mt_adopt_check_clean() {
  local package_path="$1"
  local force="${2:-false}"
  shift 2 || true
  local -a relpaths=("$@")

  if [[ -z "$package_path" ]]; then
    _mt_error "Usage: _mt_adopt_check_clean <package_path> <force> <relpath...>"
    return 1
  fi

  if [[ "$force" == "true" ]]; then
    return 0
  fi

  if [[ ${#relpaths[@]} -eq 0 ]]; then
    return 0
  fi

  if ! git -C "$package_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _mt_warning "Package source is not a git repo: ${package_path}"
    _mt_warning "Adopt will proceed without an uncommitted-changes review trail"
    return 0
  fi

  local status_output
  status_output=$(git -C "$package_path" status --porcelain -- "${relpaths[@]}" 2>/dev/null) || return 1

  if [[ -n "$status_output" ]]; then
    _mt_error "Cannot adopt: package source has uncommitted changes:"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      _mt_error "  ${line}"
    done <<< "$status_output"
    _mt_info "Commit or stash these changes, or pass --force to override"
    return 1
  fi

  return 0
}

# _mt_adopt_apply <package_path> <plan> <force>
#
# Mutation phase of `mt package install --adopt`. Reads the tab-separated plan
# from _mt_adopt_plan and applies the right action per row:
#
#   regular_file        cp dest -> source (overwrite source with home-side
#                       content), then rm dest. The user's current dotfile
#                       lives at the package source now; stow will recreate
#                       the symlink at dest in the next phase.
#   identical_to_source rm dest only. cmp -s already proved equality, so the
#                       symlink stow creates is content-safe.
#   symlink_correct     no-op (idempotent on re-runs).
#   symlink_other       no-op (don't disturb foreign symlinks).
#   missing             no-op (let stow create the symlink fresh).
#
# Prints one line per adopted file with a `git diff` review command, plus a
# final tally. <force> is accepted for interface stability but currently
# unused -- the safety guard lives in _mt_adopt_check_clean.
_mt_adopt_apply() {
  local package_path="$1"
  local plan="$2"
  local force="${3:-false}"

  if [[ -z "$package_path" ]]; then
    _mt_error "Usage: _mt_adopt_apply <package_path> <plan> <force>"
    return 1
  fi

  local adopted=0 linked=0 skipped=0
  local status source dest relpath

  while IFS=$'\t' read -r status source dest; do
    [[ -z "$status" ]] && continue
    relpath="${source#${package_path}/}"
    case "$status" in
      regular_file)
        if ! cp "$dest" "$source"; then
          _mt_error "Failed to copy ${dest} -> ${source}"
          return 1
        fi
        if ! rm "$dest"; then
          _mt_error "Failed to remove ${dest}"
          return 1
        fi
        _mt_info "adopted: ${relpath} -- review with: git -C ${package_path} diff -- ${relpath}"
        ((adopted++))
        ;;
      identical_to_source)
        if ! rm "$dest"; then
          _mt_error "Failed to remove ${dest}"
          return 1
        fi
        _mt_info "linked (no change): ${relpath}"
        ((linked++))
        ;;
      symlink_correct|symlink_other|missing)
        ((skipped++))
        ;;
      *)
        ((skipped++))
        ;;
    esac
  done <<< "$plan"

  if (( adopted > 0 || linked > 0 )); then
    _mt_info "Adopt summary: ${adopted} adopted, ${linked} linked (no change), ${skipped} skipped"
  fi

  return 0
}
