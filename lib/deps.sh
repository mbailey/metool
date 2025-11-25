#!/usr/bin/env bash
# Check dependencies for metool

# Source bash checking utilities
source "$(dirname "${BASH_SOURCE[0]}")/bash-check.sh"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unsupported"
    fi
}

# Install dependencies using Homebrew (macOS)
_mt_install_deps_brew() {
  local auto_mode=${1:-false}
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
  
  # Check for modern bash (4.0+)
  local bash_version_ok=false
  local bash_path=""
  
  # Check homebrew bash first
  for path in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [[ -x "$path" ]]; then
      local version=$("$path" --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
      local major_version=${version%%.*}
      if [[ "$major_version" -ge 4 ]]; then
        bash_version_ok=true
        bash_path="$path"
        break
      fi
    fi
  done
  
  # If no modern bash found in homebrew locations, offer to install
  if ! $bash_version_ok; then
    deps_to_install+=("bash")
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
  
  # Ask for confirmation unless in auto mode
  if [[ "$auto_mode" == "false" ]]; then
    read -p "Would you like to install these dependencies? [y/N] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Installation cancelled."
      return 1
    fi
  else
    echo "Auto-installing dependencies..."
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
  
  # Check if bash was installed and needs to be added to shells
  if [[ " ${deps_to_install[@]} " =~ " bash " ]]; then
    local new_bash_path=""
    for path in /opt/homebrew/bin/bash /usr/local/bin/bash; do
      if [[ -x "$path" ]]; then
        new_bash_path="$path"
        break
      fi
    done
    
    if [[ -n "$new_bash_path" ]] && ! grep -q "^$new_bash_path$" /etc/shells 2>/dev/null; then
      echo ""
      echo "⚠️  To use the new bash as a login shell, add it to /etc/shells:"
      echo "    echo '$new_bash_path' | sudo tee -a /etc/shells"
      echo ""
      echo "To make it your default shell:"
      echo "    chsh -s $new_bash_path"
    fi
  fi
  
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
  local interactive=${1:-true}  # Allow non-interactive mode
  
  # Check for realpath (required)
  if ! command -v realpath &>/dev/null; then
    missing_deps+=("realpath (from GNU coreutils)")
    echo "  ❌ realpath: Not found" >&2
    echo "     Install: brew install coreutils (macOS) or apt install coreutils (Linux)" >&2
  else
    echo "  ✅ realpath: Found at $(command -v realpath)"
  fi
  
  # Check for stow (required for mt install) - need version 2.4.0+
  if ! command -v stow &>/dev/null; then
    missing_deps+=("stow 2.4.0+")
    echo "  ❌ stow: Not found" >&2
    echo "     Install: brew install stow (macOS) or apt install stow (Linux)" >&2
    echo "     Required: Version 2.4.0+ for proper dot- directory support" >&2
  else
    # Check stow version - handle both X.Y.Z and X.Y formats
    local stow_version=$(stow --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [[ -n "$stow_version" ]]; then
      # Parse version components, treating missing patch as 0
      local major=$(echo "$stow_version" | cut -d. -f1)
      local minor=$(echo "$stow_version" | cut -d. -f2)
      local patch=$(echo "$stow_version" | cut -d. -f3)
      patch=${patch:-0}  # Default to 0 if no patch version

      # Check if version is 2.4.0 or later
      if [[ "$major" -gt 2 ]] || ([[ "$major" -eq 2 ]] && [[ "$minor" -ge 4 ]]); then
        echo "  ✅ stow: Found at $(command -v stow) (version $stow_version)"
      else
        missing_deps+=("stow 2.4.0+ (current: $stow_version)")
        echo "  ❌ stow: Version $stow_version is too old (need 2.4.0+)" >&2
        echo "     The dot- directory feature requires stow 2.4.0 or later" >&2
        echo "     Upgrade: brew upgrade stow (macOS) or update your package manager" >&2
      fi
    else
      echo "  ⚠️  stow: Found at $(command -v stow) but couldn't determine version"
      echo "     Required: Version 2.4.0+ for proper dot- directory support" >&2
    fi
  fi
  
  # Check for modern bash (4.0+) - required for metool
  if _mt_check_bash_version; then
    echo "  ✅ bash: Modern bash ($METOOL_BASH_VERSION) found at $METOOL_BASH_PATH"
    local bash_version_ok=true
    local bash_path="$METOOL_BASH_PATH"
  else
    local bash_version_ok=false
    local bash_path=""
    local system_bash_version=$(/bin/bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  fi
  
  # Check if /usr/bin/env bash finds the right version
  if ! _mt_check_env_bash; then
    local env_bash_version=$(env bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    
    if ! $bash_version_ok; then
      # No modern bash installed
      missing_deps+=("bash 4.0+ (metool requires modern bash)")
      echo "  ❌ bash: System bash is too old (${system_bash_version:-unknown}), need 4.0+" >&2
      echo "     Install: brew install bash (macOS)" >&2
      
      # Offer to install if interactive
      if [[ "$interactive" == "true" ]]; then
        if _mt_install_modern_bash true; then
          # Re-check after installation
          if _mt_check_bash_version; then
            bash_version_ok=true
            bash_path="$METOOL_BASH_PATH"
            missing_deps=("${missing_deps[@]/bash 4.0+*/}")
            echo "     ✅ bash: Modern bash ($METOOL_BASH_VERSION) now at $METOOL_BASH_PATH"
          fi
        fi
      fi
    else
      # Modern bash installed but not in PATH
      echo "  ⚠️  bash: 'env bash' finds old version ($env_bash_version)" >&2
      echo "     Modern bash at $bash_path is not in PATH priority" >&2
      
      # Check if it's already configured in shell RC
      if _mt_is_bash_path_configured "$bash_path"; then
        echo "     ℹ️  PATH already configured in shell config (restart shell to apply)" >&2
        # Don't add to warnings since it's already fixed
      else
        warnings+=("env bash finds old version ($env_bash_version)")
        echo "     Add to PATH: export PATH=\"$(dirname $bash_path):\$PATH\"" >&2
        
        # Try to fix PATH configuration
        if [[ "$interactive" == "true" ]]; then
          _mt_ensure_bash_in_path "$bash_path" true
        fi
      fi
    fi
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
  
  # Check for symlinks command (required for mt doctor and mt clean)
  if ! command -v symlinks &>/dev/null; then
    missing_deps+=("symlinks (for broken symlink detection)")
    echo "  ❌ symlinks: Not found" >&2
    echo "     Install: brew install symlinks (macOS) or apt install symlinks (Linux)" >&2
    echo "     Note: Required for 'mt doctor' and 'mt clean'" >&2
  else
    echo "  ✅ symlinks: Found at $(command -v symlinks)"
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
  local auto_fix=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)
        install_flag=true
        shift
        ;;
      --fix|--auto)
        auto_fix=true
        install_flag=true
        shift
        ;;
      -h|--help)
        echo "Usage: mt deps [OPTIONS]"
        echo ""
        echo "Check and manage metool dependencies"
        echo ""
        echo "Options:"
        echo "  --install    Offer to install missing dependencies (macOS/Homebrew only)"
        echo "  --fix, --auto  Automatically install missing dependencies without prompting"
        echo "  -h, --help   Show this help message"
        echo ""
        echo "Examples:"
        echo "  mt deps           # Check dependencies"
        echo "  mt deps --install # Check and offer to install missing deps"
        echo "  mt deps --fix     # Automatically fix all missing dependencies"
        return 0
        ;;
      *)
        echo "Usage: mt deps [--install]"
        echo ""
        echo "Options:"
        echo "  --install    Offer to install missing dependencies (macOS/Homebrew only)"
        return 1
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
      if ! $auto_fix; then
        echo "🍺 Homebrew detected. Would you like to install missing dependencies?"
      else
        echo "🍺 Auto-fixing missing dependencies with Homebrew..."
      fi
      echo ""
      _mt_install_deps_brew "$auto_fix"
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
    _mt_install_deps_brew "$auto_fix"
  fi
}