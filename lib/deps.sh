#!/usr/bin/env bash
# Check dependencies for metool

# Install dependencies using Homebrew (macOS)
_mt_install_deps_brew() {
  local deps_to_install=()
  
  # Check each dependency
  if ! command -v realpath &>/dev/null; then
    deps_to_install+=("coreutils")
  fi
  
  if ! command -v stow &>/dev/null; then
    deps_to_install+=("stow")
  fi
  
  # Check for bash-completion
  local bash_completion_found=false
  if [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] || \
     [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]]; then
    bash_completion_found=true
  fi
  
  if ! $bash_completion_found; then
    deps_to_install+=("bash-completion@2")
  fi
  
  # Check for bats (test framework)
  if ! command -v bats &>/dev/null; then
    deps_to_install+=("bats-core")
  fi
  
  if [[ ${#deps_to_install[@]} -eq 0 ]]; then
    echo "✅ All dependencies are already installed!"
    return 0
  fi
  
  echo "The following Homebrew packages will be installed:"
  for dep in "${deps_to_install[@]}"; do
    echo "  - $dep"
  done
  echo ""
  
  # Ask for confirmation
  read -p "Would you like to install these dependencies? [y/N] " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    return 1
  fi
  
  echo "Installing dependencies..."
  for dep in "${deps_to_install[@]}"; do
    echo "Installing $dep..."
    if brew install "$dep"; then
      echo "✅ $dep installed successfully"
    else
      echo "❌ Failed to install $dep" >&2
      return 1
    fi
  done
  
  echo ""
  echo "✅ All dependencies installed successfully!"
  
  # Check if bashrc needs updating for bash-completion
  if [[ " ${deps_to_install[@]} " =~ " bash-completion@2 " ]]; then
    echo ""
    echo "⚠️  To enable bash-completion, add this to your ~/.bashrc:"
    echo '    [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"'
  fi
  
  return 0
}

_mt_check_deps() {
  local missing_deps=()
  local warnings=()
  
  # Check for realpath (required)
  if ! command -v realpath &>/dev/null; then
    missing_deps+=("realpath (from GNU coreutils)")
    echo "  ❌ realpath: Not found" >&2
    echo "     Install: brew install coreutils (macOS) or apt install coreutils (Linux)" >&2
  else
    echo "  ✅ realpath: Found at $(command -v realpath)"
  fi
  
  # Check for stow (required for mt install)
  if ! command -v stow &>/dev/null; then
    missing_deps+=("stow")
    echo "  ❌ stow: Not found" >&2
    echo "     Install: brew install stow (macOS) or apt install stow (Linux)" >&2
  else
    echo "  ✅ stow: Found at $(command -v stow)"
  fi
  
  # Check for GNU ln with -r support (optional but recommended)
  local ln_status="not found"
  if ln -r -s /dev/null /tmp/mt_test_ln_$$ 2>/dev/null; then
    command rm -f /tmp/mt_test_ln_$$
    ln_status="supports -r"
    echo "  ✅ ln: Found at $(command -v ln) (supports -r for relative symlinks)"
  elif command -v gln >/dev/null 2>&1 && gln -r -s /dev/null /tmp/mt_test_gln_$$ 2>/dev/null; then
    command rm -f /tmp/mt_test_gln_$$
    ln_status="gln available"
    echo "  ✅ gln: Found at $(command -v gln) (will use for relative symlinks)"
  else
    warnings+=("GNU ln with -r support (for relative symlinks)")
    echo "  ⚠️  ln: No GNU ln with -r support found" >&2
    echo "     Install: brew install coreutils (macOS)" >&2
  fi
  
  # Check for bash-completion (optional but recommended for alias completion)
  local bash_completion_found=false
  local bash_completion_paths=(
    "/opt/homebrew/etc/profile.d/bash_completion.sh"
    "/usr/local/etc/profile.d/bash_completion.sh"
    "/etc/bash_completion"
    "/usr/share/bash-completion/bash_completion"
  )
  
  for path in "${bash_completion_paths[@]}"; do
    if [[ -r "$path" ]]; then
      bash_completion_found=true
      echo "  ✅ bash-completion: Found at $path"
      break
    fi
  done
  
  if ! $bash_completion_found; then
    warnings+=("bash-completion (for alias completion support)")
    echo "  ⚠️  bash-completion: Not found" >&2
    echo "     Install: brew install bash-completion@2 (macOS) or apt install bash-completion (Linux)" >&2
    echo "     Note: Alias completion will not work without this" >&2
  fi
  
  # Check if _command_offset is available (indicates bash-completion is loaded)
  if type -t _command_offset &>/dev/null; then
    echo "  ✅ bash-completion loaded: _command_offset function available"
  elif $bash_completion_found; then
    echo "  ⚠️  bash-completion installed but not loaded in current shell" >&2
    echo "     Add to ~/.bashrc: [[ -r \"/opt/homebrew/etc/profile.d/bash_completion.sh\" ]] && . \"/opt/homebrew/etc/profile.d/bash_completion.sh\"" >&2
  fi
  
  # Check for bats (optional, for running tests)
  if ! command -v bats &>/dev/null; then
    warnings+=("bats-core (for running tests)")
    echo "  ⚠️  bats: Not found" >&2
    echo "     Install: brew install bats-core (macOS) or npm install -g bats (cross-platform)" >&2
    echo "     Note: Required for running 'make test'" >&2
  else
    echo "  ✅ bats: Found at $(command -v bats)"
  fi
  
  # Summary
  echo ""
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "❌ Missing required dependencies:" >&2
    for dep in "${missing_deps[@]}"; do
      echo "   - $dep" >&2
    done
    echo "" >&2
    echo "Metool may not function correctly without these dependencies." >&2
    return 1
  else
    echo "✅ All required dependencies found!"
  fi
  
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️  Optional dependencies missing:" >&2
    for warning in "${warnings[@]}"; do
      echo "   - $warning" >&2
    done
  fi
  
  return 0
}

# Add a mt command to check dependencies
_mt_deps() {
  local install_flag=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)
        install_flag=true
        shift
        ;;
      *)
        echo "Usage: mt deps [--install]"
        echo "  --install    Offer to install missing dependencies (macOS/Homebrew only)"
        return 0
        ;;
    esac
  done
  
  echo "Checking metool dependencies..."
  echo ""
  
  # Check dependencies
  if ! _mt_check_deps; then
    # Dependencies are missing
    if $install_flag && command -v brew &>/dev/null; then
      echo ""
      echo "🍺 Homebrew detected. Would you like to install missing dependencies?"
      echo ""
      _mt_install_deps_brew
    elif $install_flag && ! command -v brew &>/dev/null; then
      echo ""
      echo "❌ --install flag requires Homebrew, which was not found."
      echo "   Please install Homebrew first: https://brew.sh"
    elif command -v brew &>/dev/null; then
      echo ""
      echo "💡 Tip: Run 'mt deps --install' to automatically install missing dependencies with Homebrew"
    fi
  elif $install_flag; then
    # All deps installed but --install was used
    _mt_install_deps_brew
  fi
}