# Canonical URL parser for metool.
#
# Replaces (via callers' migration in MT-72/migrate-001):
#   _mt_parse_git_url         (lib/repos.sh)            URL on disk -> .repos.txt entry
#   _mt_repo_url              (lib/git.sh, URL-build)   .repos.txt entry -> fetchable URL
#   URL recognition inline in _mt_git_manifest_parse    (lib/git/manifest.sh)
#
# Design (see ../../behaviour-matrix.md and MT-72 README.md):
#   - One parser produces structured fields via a caller-supplied associative
#     array (nameref). Bash 4+ is already required (install.sh, lib/bash-check.sh).
#   - String-output helpers compose on top: _mt_url_canonicalise (replaces
#     _mt_parse_git_url) and _mt_url_to_fetch (replaces _mt_repo_url's
#     URL-building branches; the local-dir branch is NOT this file's concern --
#     see D7 in the matrix).
#   - The @version strip uses the anchored regex `@[^/:@]+$`, NOT `%%@*`. The
#     greedy `%%@*` is the bug class D9 documents -- it eats `git@` and yields
#     repo_name=git for every `git@host:owner/repo` input.
#   - Regex classification order is fixed: more-specific shapes first. The
#     alias-form catch-all (`^([^/:@]+):(.+)$`) MUST come after the http(s)://
#     and user@host: branches -- it would otherwise shadow them. MT-68
#     documented this silent-shadowing bug class; the test suite (tests-001)
#     latches a guard against it.

# _mt_url_parse <url> <out_var_name>
#
# Parse a git URL/spec and populate the caller's associative array. The caller
# MUST `declare -A <out_var_name>` before calling -- otherwise the nameref
# assignments silently misbehave (Bash quirk: numeric-indexed arrays accept
# string subscripts as 0).
#
# Fields:
#   type            ssh | https | http | alias | shorthand | local
#   user            user@ part (SSH only; empty for other types)
#   host            hostname (identity suffix split out into [identity])
#   identity        _identity suffix (SSH and alias; empty if none)
#   owner           first path segment
#   repo_name       basename of path (.git already stripped)
#   path            full path after the host (no leading /)
#   has_git_suffix  1 if input had .git suffix, else 0
#   version         @version suffix if present (e.g. v1.2.3)
#   original        verbatim input
#   error           non-empty on parse failure
#
# Returns 0 on success, 1 on unparseable input.
_mt_url_parse() {
  local url="${1:?url required}"
  local -n _mt_url_out=${2:?out var name required}

  _mt_url_out=()
  _mt_url_out[original]="$url"
  _mt_url_out[type]=""
  _mt_url_out[user]=""
  _mt_url_out[host]=""
  _mt_url_out[identity]=""
  _mt_url_out[owner]=""
  _mt_url_out[repo_name]=""
  _mt_url_out[path]=""
  _mt_url_out[has_git_suffix]=0
  _mt_url_out[version]=""
  _mt_url_out[error]=""

  if [[ -z "$url" ]]; then
    _mt_url_out[error]="empty input"
    return 1
  fi

  # Local paths: parser does NOT touch the filesystem (D7). Caller-side helper
  # (_mt_repo_origin_url, migrate-001) reads .git/config when needed.
  if [[ "$url" == /* ]] || [[ "$url" == ./* ]] || [[ "$url" == ../* ]] \
     || [[ "$url" == "." ]] || [[ "$url" == ".." ]] \
     || [[ "$url" == "~" ]] || [[ "$url" == "~/"* ]]; then
    _mt_url_out[type]=local
    _mt_url_out[path]="$url"
    return 0
  fi

  # Step 1: underscore-alias expansion (D5). Always runs first so the rest of
  # the parser sees the canonical `host_identity:` form.
  local working
  if ! working=$(_mt_url__expand_underscore_alias "$url"); then
    _mt_url_out[error]="invalid auto-identity format (expected owner/repo after _:)"
    return 1
  fi

  # Step 2: strip @version (D8/D9). The regex is anchored at end with no
  # `/:@` in the version token -- this catches `owner/repo@v1.2.3` without
  # eating `git@host:owner/repo` (the tail past the LAST `@` in that case
  # contains both `:` and `/`, so the regex fails to match).
  if [[ "$working" =~ ^(.+)@([^/:@]+)$ ]]; then
    local _v_prefix="${BASH_REMATCH[1]}"
    # Require the prefix to actually look like a URL/path. Avoids stripping
    # nonsense like `git@host` (no `:` or `/` before the `@`).
    if [[ "$_v_prefix" == *:* || "$_v_prefix" == */* ]]; then
      _mt_url_out[version]="${BASH_REMATCH[2]}"
      working="$_v_prefix"
    fi
  fi

  # Step 3: detect and strip the trailing .git suffix.
  if [[ "$working" == *.git ]]; then
    _mt_url_out[has_git_suffix]=1
    working="${working%.git}"
  fi

  # Step 4: classify. ORDER MATTERS. The alias-form regex is a catch-all that
  # would shadow https:// and user@host: -- it MUST come after them.
  local classified=0

  if [[ "$working" =~ ^([^@/:]+)@([^:]+):(.+)$ ]]; then
    # SSH: user@host:path
    _mt_url_out[type]=ssh
    _mt_url_out[user]="${BASH_REMATCH[1]}"
    local _raw_host="${BASH_REMATCH[2]}"
    _mt_url_out[path]="${BASH_REMATCH[3]}"
    _mt_url__split_identity "$_raw_host" _mt_url_out
    classified=1
  elif [[ "$working" =~ ^(https?)://([^/]+)/(.+)$ ]]; then
    # HTTP / HTTPS
    _mt_url_out[type]="${BASH_REMATCH[1]}"
    _mt_url_out[host]="${BASH_REMATCH[2]}"
    _mt_url_out[path]="${BASH_REMATCH[3]}"
    classified=1
  elif [[ "$working" =~ ^([^/:@]+\.[^/:@]+)/(.+)$ ]]; then
    # Host-form shorthand (a dot in the first segment marks it as a hostname,
    # distinguishing it from bare `owner/repo`).
    _mt_url_out[type]=shorthand
    _mt_url_out[host]="${BASH_REMATCH[1]}"
    _mt_url_out[path]="${BASH_REMATCH[2]}"
    classified=1
  elif [[ "$working" =~ ^([^/:@]+):(.+)$ ]]; then
    # ssh_config Host alias (or post-expansion `host_identity:` form).
    _mt_url_out[type]=alias
    local _raw_alias_host="${BASH_REMATCH[1]}"
    _mt_url_out[path]="${BASH_REMATCH[2]}"
    # Only split identity when the alias host looks like a real hostname
    # (contains a `.`). Pure aliases like `failmode`, `ms2` keep the
    # underscore as part of the alias name itself.
    if [[ "$_raw_alias_host" =~ ^([^_]+\.[^_]+)_(.+)$ ]]; then
      _mt_url_out[host]="${BASH_REMATCH[1]}"
      _mt_url_out[identity]="${BASH_REMATCH[2]}"
    else
      _mt_url_out[host]="$_raw_alias_host"
    fi
    classified=1
  elif [[ "$working" =~ ^:([^/]+)/(.+)$ ]]; then
    # SSH shorthand: `:owner/repo` -- default host, default to SSH.
    _mt_url_out[type]=shorthand
    _mt_url_out[host]="${MT_GIT_HOST_DEFAULT:-github.com}"
    _mt_url_out[path]="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    classified=1
  elif [[ "$working" =~ ^([^/:@]+)/([^/:@]+)$ ]]; then
    # Bare `owner/repo` -- default host, default protocol applied at
    # fetch-URL build time.
    _mt_url_out[type]=shorthand
    _mt_url_out[host]="${MT_GIT_HOST_DEFAULT:-github.com}"
    _mt_url_out[path]="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    classified=1
  fi

  if (( classified == 0 )); then
    _mt_url_out[error]="unrecognised URL shape"
    return 1
  fi

  _mt_url__split_path "${_mt_url_out[path]}" _mt_url_out
  return 0
}

# Internal: expand `_alias:owner/repo` shorthand (D5).
# `_alias:owner/repo`  -> `github.com_alias:owner/repo`
# `_:owner/repo`       -> `github.com_owner:owner/repo` (auto-identity)
# Echoes the result; returns 1 on invalid auto-identity (no `owner/repo`).
_mt_url__expand_underscore_alias() {
  local repo="$1"
  if [[ "$repo" =~ ^_([^:]*):(.+)$ ]]; then
    local _ua_identity="${BASH_REMATCH[1]}"
    local _ua_path="${BASH_REMATCH[2]}"
    if [[ -z "$_ua_identity" ]]; then
      if [[ "$_ua_path" =~ ^([^/]+)/(.+)$ ]]; then
        echo "github.com_${BASH_REMATCH[1]}:${_ua_path}"
      else
        echo "$repo"
        return 1
      fi
    else
      echo "github.com_${_ua_identity}:${_ua_path}"
    fi
  else
    echo "$repo"
  fi
}

# Internal: split `github.com_identity` -> host=github.com, identity=identity.
# Pure hostnames (no underscore) pass through with identity="".
_mt_url__split_identity() {
  local raw_host="$1"
  local -n _mt_url_si_out=$2
  if [[ "$raw_host" =~ ^([^_]+)_(.+)$ ]]; then
    _mt_url_si_out[host]="${BASH_REMATCH[1]}"
    _mt_url_si_out[identity]="${BASH_REMATCH[2]}"
  else
    _mt_url_si_out[host]="$raw_host"
  fi
}

# Internal: derive `owner` (first segment) and `repo_name` (basename) from a
# path string. The .git suffix is already stripped by the caller.
_mt_url__split_path() {
  local path="$1"
  local -n _mt_url_sp_out=$2
  _mt_url_sp_out[repo_name]="${path##*/}"
  if [[ "$path" == */* ]]; then
    _mt_url_sp_out[owner]="${path%%/*}"
  else
    _mt_url_sp_out[owner]=""
  fi
}

# _mt_url_canonicalise <url>
#
# Echo the .repos.txt canonical form. Replaces _mt_parse_git_url.
#
# Conventions (per behaviour matrix + D2/D5):
#   ssh, default host, no identity  -> owner/repo  (drops host info)
#   ssh, with identity              -> _identity:owner/repo  (round-trip form)
#   ssh, non-default host           -> host:owner/repo
#   https / http                    -> owner/repo  (drops host info; matches
#                                      _mt_parse_git_url's existing behaviour)
#   alias, no identity              -> host:owner/repo  (alias preserved)
#   alias, with identity            -> _identity:owner/repo
#   shorthand                       -> owner/repo (already canonical)
#   local                           -> return 1 (no canonical .repos.txt form)
#
# Returns 0 on success, 1 on unparseable or non-canonicalisable input.
_mt_url_canonicalise() {
  local url="${1:?url required}"
  local -A _mt_url_c_p
  if ! _mt_url_parse "$url" _mt_url_c_p; then
    return 1
  fi

  local default_host="${MT_GIT_HOST_DEFAULT:-github.com}"
  local host="${_mt_url_c_p[host]}"
  local path="${_mt_url_c_p[path]}"
  local identity="${_mt_url_c_p[identity]}"

  case "${_mt_url_c_p[type]}" in
    ssh)
      if [[ -n "$identity" ]]; then
        echo "_${identity}:${path}"
      elif [[ "$host" == "$default_host" ]]; then
        echo "$path"
      else
        echo "${host}:${path}"
      fi
      ;;
    https|http)
      echo "$path"
      ;;
    alias)
      if [[ -n "$identity" ]]; then
        echo "_${identity}:${path}"
      else
        echo "${host}:${path}"
      fi
      ;;
    shorthand)
      echo "$path"
      ;;
    local)
      return 1
      ;;
  esac
}

# _mt_url_to_fetch <url>
#
# Echo a fetchable URL (suitable for `git clone`). Replaces _mt_repo_url's
# URL-building branches. The local-directory branch is OUT OF SCOPE here --
# callers handling on-disk paths must use _mt_repo_origin_url (added in
# migrate-001) which reads .git/config.
#
# Unparseable input passes through unchanged, matching _mt_repo_url's
# silent fallthrough.
_mt_url_to_fetch() {
  local url="${1:?url required}"
  local -A _mt_url_f_p
  if ! _mt_url_parse "$url" _mt_url_f_p; then
    echo "$url"
    return 1
  fi

  local host="${_mt_url_f_p[host]}"
  local path="${_mt_url_f_p[path]}"
  local identity="${_mt_url_f_p[identity]}"
  local user="${_mt_url_f_p[user]:-git}"

  case "${_mt_url_f_p[type]}" in
    ssh)
      [[ -n "$identity" ]] && host="${host}_${identity}"
      echo "${user}@${host}:${path}.git"
      ;;
    https|http)
      echo "${_mt_url_f_p[type]}://${host}/${path}.git"
      ;;
    alias)
      # ssh_config resolves User via its `User` directive. The literal `git@`
      # is required by git's syntax (host:path without `git@` is a local path).
      [[ -n "$identity" ]] && host="${host}_${identity}"
      echo "git@${host}:${path}.git"
      ;;
    shorthand)
      local protocol="${MT_GIT_PROTOCOL_DEFAULT:-git}"
      if [[ "$protocol" == "ssh" || "$protocol" == "git" ]]; then
        echo "git@${host}:${path}.git"
      else
        echo "${protocol}://${host}/${path}.git"
      fi
      ;;
    local)
      # Local paths aren't fetchable URLs by themselves. Return the path
      # unchanged for diagnostics; callers should route through
      # _mt_repo_origin_url instead.
      echo "$url"
      return 1
      ;;
  esac
}
