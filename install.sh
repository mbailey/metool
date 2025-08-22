#!/usr/bin/env bash
#
# If running with old bash, try to find and use modern bash
# But only if we're running from a file (not piped from curl)
if [[ "${BASH_VERSION%%.*}" -lt 4 ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    for bash_path in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$bash_path" ]]; then
            exec "$bash_path" "$0" "$@"
        fi
    done
fi
#
# Metool installer - Works on fresh macOS and Linux systems
# This script installs metool and its dependencies
#
# Quick install:
#   curl -sSL https://raw.githubusercontent.com/mbailey/metool/master/install.sh | bash
#
# Or clone and run:
#   git clone https://github.com/mbailey/metool.git
#   cd metool && ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[installer]${NC} $*"
}

error() {
    echo -e "${RED}[installer]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[installer]${NC} $*"
}

info() {
    echo -e "${BLUE}[installer]${NC} $*"
}

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies on macOS
install_macos_deps() {
    log "Checking macOS dependencies..."
    
    # Check for Homebrew
    if ! command_exists brew; then
        error "Homebrew is required but not installed."
        info "Install from: https://brew.sh"
        exit 1
    fi
    
    local deps_to_install=()
    
    # Check for GNU coreutils (realpath)
    if ! command_exists realpath; then
        warn "GNU coreutils (realpath) not found"
        deps_to_install+=("coreutils")
    else
        log "✓ GNU coreutils installed"
    fi
    
    # Check for GNU Stow
    if ! command_exists stow; then
        warn "GNU Stow not found"
        deps_to_install+=("stow")
    else
        log "✓ GNU Stow installed"
    fi
    
    # Check for modern bash
    if ! /opt/homebrew/bin/bash --version &>/dev/null && ! /usr/local/bin/bash --version &>/dev/null; then
        warn "Modern bash not found"
        deps_to_install+=("bash")
    else
        log "✓ Modern bash installed"
    fi
    
    # Optional: bash-completion
    if ! brew list bash-completion@2 &>/dev/null; then
        info "bash-completion@2 not found (optional)"
        read -p "Install bash-completion@2 for better tab completion? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            deps_to_install+=("bash-completion@2")
        fi
    else
        log "✓ bash-completion@2 installed"
    fi
    
    # Install missing dependencies
    if [ ${#deps_to_install[@]} -gt 0 ]; then
        log "Installing dependencies: ${deps_to_install[*]}"
        brew install "${deps_to_install[@]}"
    else
        log "All required dependencies are installed"
    fi
}

# Install dependencies on Linux
install_linux_deps() {
    log "Checking Linux dependencies..."
    
    local deps_to_install=()
    
    # Check for GNU coreutils (should be present)
    if ! command_exists realpath; then
        deps_to_install+=("coreutils")
    else
        log "✓ GNU coreutils installed"
    fi
    
    # Check for GNU Stow
    if ! command_exists stow; then
        deps_to_install+=("stow")
    else
        log "✓ GNU Stow installed"
    fi
    
    # Install missing dependencies
    if [ ${#deps_to_install[@]} -gt 0 ]; then
        if command_exists apt-get; then
            log "Installing with apt: ${deps_to_install[*]}"
            sudo apt-get update && sudo apt-get install -y "${deps_to_install[@]}"
        elif command_exists yum; then
            log "Installing with yum: ${deps_to_install[*]}"
            sudo yum install -y "${deps_to_install[@]}"
        elif command_exists pacman; then
            log "Installing with pacman: ${deps_to_install[*]}"
            sudo pacman -S --noconfirm "${deps_to_install[@]}"
        else
            error "Could not detect package manager"
            error "Please install manually: ${deps_to_install[*]}"
            exit 1
        fi
    else
        log "All required dependencies are installed"
    fi
}

# Get the correct bash path
get_bash_path() {
    # Prefer homebrew bash on macOS
    if [[ -x /opt/homebrew/bin/bash ]]; then
        echo "/opt/homebrew/bin/bash"
    elif [[ -x /usr/local/bin/bash ]]; then
        echo "/usr/local/bin/bash"
    else
        echo "/usr/bin/env bash"
    fi
}

# Main installation
main() {
    log "Starting Metool installation..."
    
    # Detect OS
    local os=$(detect_os)
    if [[ "$os" == "unsupported" ]]; then
        error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    # Check if we're running via curl or from a cloned repo
    local install_mode="repo"
    local MT_ROOT=""
    
    if [[ ! -f "${BASH_SOURCE[0]}" ]] || [[ "${BASH_SOURCE[0]}" == "/dev/stdin" ]] || [[ -z "${BASH_SOURCE[0]}" ]]; then
        # Running via curl - need to clone the repo
        install_mode="curl"
        log "Running via curl - bootstrapping metool..."
        
        # Clone to temp directory first
        local temp_dir=$(mktemp -d)
        log "Cloning metool to temporary directory..."
        if ! git clone https://github.com/mbailey/metool.git "$temp_dir/metool"; then
            error "Failed to clone metool repository"
            error "Please check your internet connection and try again"
            rm -rf "$temp_dir"
            exit 1
        fi
        
        # Now we can use metool to install itself properly
        log "Using metool to install itself..."
        
        # Source metool from temp location using proper bash
        local bash_to_use="/usr/bin/env bash"
        for bash_path in /opt/homebrew/bin/bash /usr/local/bin/bash; do
            if [[ -x "$bash_path" ]]; then
                bash_to_use="$bash_path"
                break
            fi
        done
        
        # Source metool from temp location
        source "$temp_dir/metool/shell/mt"
        
        # Use mt clone to place metool in the proper location
        log "Cloning metool to canonical location..."
        mt clone https://github.com/mbailey/metool.git
        
        # Get the canonical path where it was cloned
        MT_ROOT="${MT_GIT_BASE_DIR:-$HOME/Code}/github.com/mbailey/metool"
        
        # Clean up temp directory
        rm -rf "$temp_dir"
        
        log "Metool cloned to: $MT_ROOT"
    else
        # Running from cloned repository
        install_mode="repo"
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        MT_ROOT="$SCRIPT_DIR"
    fi
    
    # Install dependencies
    if [[ "$os" == "macos" ]]; then
        install_macos_deps
    else
        install_linux_deps
    fi
    
    # Update mtbin to use correct bash
    local bash_path=$(get_bash_path)
    log "Using bash at: $bash_path"
    
    # Create temporary mtbin for installation
    cat > "$MT_ROOT/bin/mtbin-install" << EOF
#!${bash_path}
# Temporary mtbin for installation
# This sources metool directly from the repository

# Source metool from repository
source "$MT_ROOT/shell/mt"

# Pass all arguments to mt
mt "\$@"
EOF
    chmod +x "$MT_ROOT/bin/mtbin-install"
    
    # Run metool install using temporary mtbin
    log "Installing metool..."
    "$MT_ROOT/bin/mtbin-install" install
    
    # Clean up temporary file
    rm "$MT_ROOT/bin/mtbin-install"
    
    # Note: We don't update mtbin shebang since it's a symlink
    # The mtbin script itself handles finding the right bash at runtime
    
    # Detect user's shell
    local user_shell=$(basename "$SHELL")
    log "Detected shell: $user_shell"
    
    # Configure shell integration
    local shell_config=""
    case "$user_shell" in
        bash)
            shell_config="$HOME/.bashrc"
            ;;
        zsh)
            shell_config="$HOME/.zshrc"
            ;;
        *)
            warn "Unknown shell: $user_shell"
            shell_config=""
            ;;
    esac
    
    if [[ -n "$shell_config" ]]; then
        # Check if metool is already in shell config
        if grep -q "metool" "$shell_config" 2>/dev/null; then
            log "Metool already configured in $shell_config"
        else
            info "Adding metool to $shell_config"
            cat >> "$shell_config" << 'EOF'

# Metool configuration
if [[ -f "$HOME/.metool/shell/metool/mt" ]]; then
    source "$HOME/.metool/shell/metool/mt"
fi
# Add metool bin to PATH for mtbin command
export PATH="$HOME/.metool/bin:$PATH"
EOF
            log "Added metool configuration to $shell_config"
        fi
        
        # Special handling for zsh users
        if [[ "$user_shell" == "zsh" ]]; then
            warn "Note: You're using zsh. The 'mt' function requires bash."
            info "You can use 'mtbin' command which works in any shell."
            info "Example: mtbin install package-name"
            info ""
            info "For full functionality, consider using bash or running:"
            info "  exec bash"
        fi
    fi
    
    log "✅ Metool installation complete!"
    info ""
    info "Next steps:"
    info "1. Reload your shell: source $shell_config"
    info "   Or start a new terminal"
    info "2. Test metool: mt --help"
    info "3. Install packages: mt clone https://github.com/mbailey/metool-packages.git"
    info ""
    
    if [[ "$user_shell" == "zsh" ]]; then
        info "For zsh users: Use 'mtbin' instead of 'mt' for commands"
    fi
}

# Run main function
main "$@"