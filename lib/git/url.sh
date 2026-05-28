# Canonical URL parser for metool.
#
# Design (see ../../behaviour-matrix.md and MT-72 README.md):
#   - One parser produces structured fields via a caller-supplied associative
#     array (nameref). Bash 4+ is already required (install.sh, lib/bash-check.sh).
#   - String-output helpers compose on top: _mt_url_canonicalise emits the
#     .repos.txt entry shape; _mt_url_to_fetch emits a fetchable URL. The
#     local-dir branch (read .git/config) lives in _mt_repo_origin_url -- the
#     parser does not touch the filesystem (D7 in the matrix).
#   - The @version strip uses the anchored regex `@[^/:@]+$`, NOT `%%@*`. The
#     greedy `%%@*` is the bug class D9 documents -- it eats `git@` and yields
#     repo_name=git for every `git@host:owner/repo` input.
#   - Regex classification order is fixed: more-specific shapes first. The
#     alias-form catch-all (`^([^/:@]+):(.+)$`) MUST come after the http(s)://
#     and user@host: branches -- it would otherwise shadow them. MT-68
#     documented this silent-shadowing bug class; tests/url.bats latches a
#     guard against it.

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
  # _mt_repo_origin_url reads .git/config when needed.
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
# Echo the .repos.txt canonical form.
#
# Conventions (per behaviour matrix + D2/D5):
#   ssh, default host, no identity  -> owner/repo  (drops host info)
#   ssh, with identity              -> _identity:owner/repo  (round-trip form)
#   ssh, non-default host           -> host:owner/repo
#   https / http                    -> owner/repo  (drops host info)
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
# Echo a fetchable URL (suitable for `git clone`). The local-directory branch
# is OUT OF SCOPE here -- callers handling on-disk paths must use
# _mt_repo_origin_url, which reads .git/config.
#
# Unparseable input passes through unchanged (silent fallthrough for callers
# that may receive arbitrary strings).
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

# _mt_url_to_host <url>
#
# Echo the SSH/connection host for ControlMaster purposes. This is the host
# string the SSH client actually keys its master socket off -- so ssh_config
# `Host` aliases (no dot) return the alias verbatim, identity-suffixed hosts
# return `host_identity` (matching the form `_mt_url_to_fetch` emits), and
# port suffixes on `ssh://` URLs are stripped.
#
# Empty output (and rc=1) for inputs with no remote host: local paths and
# unparseable strings. Callers (the parallel pre-warm pass) treat empty as
# "skip this repo for pre-warm".
_mt_url_to_host() {
  local url="${1:?url required}"

  # ssh:// is not produced by _mt_url_parse (the canonical parser focuses on
  # the forms .repos.txt accepts). Handle it inline here -- it has a real
  # ControlMaster identity and would otherwise misclassify.
  if [[ "$url" =~ ^ssh://([^@/]+@)?([^:/]+)(:[0-9]+)?(/.*)?$ ]]; then
    echo "${BASH_REMATCH[2]}"
    return 0
  fi

  local -A _mt_url_h_p
  if ! _mt_url_parse "$url" _mt_url_h_p; then
    return 1
  fi

  local host="${_mt_url_h_p[host]}"
  local identity="${_mt_url_h_p[identity]}"

  case "${_mt_url_h_p[type]}" in
    ssh|alias)
      # Identity-suffixed hosts get their own ControlMaster socket: the
      # ssh_config IdentityFile branch keys off the alias, not the resolved
      # hostname, so distinct aliases must produce distinct host strings.
      [[ -n "$identity" ]] && host="${host}_${identity}"
      echo "$host"
      ;;
    https|http|shorthand)
      echo "$host"
      ;;
    local)
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

# _mt_repo_origin_url <repo>
#
# Resolve a repo argument to a fetchable URL, including the disk case.
#
# If <repo> is an existing directory, echoes `git -C <repo> config --get
# remote.origin.url` (D7 -- the only filesystem-touching branch). Otherwise
# delegates to _mt_url_to_fetch.
#
# Use this from callers (e.g. mt clone, mt module add) that accept either a
# local dir or a URL spec. Pure URL-shape callers should call _mt_url_to_fetch
# directly.
_mt_repo_origin_url() {
  local repo="${1:-.}"
  if [[ -d "$repo" ]]; then
    git -C "$repo" config --get remote.origin.url
    return
  fi
  _mt_url_to_fetch "$repo"
}
