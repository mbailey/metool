#!/usr/bin/env bash
# Bash version checking and fixing utilities for metool

# Check if we have modern bash (4.0+)
# Returns 0 if bash is OK, 1 if not
# Sets METOOL_BASH_PATH to the path of modern bash if found
_mt_check_bash_version() {
    local min_version=${1:-4}
    METOOL_BASH_PATH=""
    METOOL_BASH_VERSION=""
    
    # Check homebrew bash locations first
    for path in /opt/homebrew/bin/bash /usr/local/bin/bash /usr/bin/bash /bin/bash; do
        if [[ -x "$path" ]]; then
            local version=$("$path" --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            local major_version=${version%%.*}
            if [[ "$major_version" -ge "$min_version" ]]; then
                METOOL_BASH_PATH="$path"
                METOOL_BASH_VERSION="$version"
                return 0
            fi
        fi
    done
    
    return 1
}

# Check if env bash finds modern bash
# Returns 0 if OK, 1 if not
_mt_check_env_bash() {
    local min_version=${1:-4}
    local env_bash_version=$(env bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local env_bash_major=${env_bash_version%%.*}
    
    if [[ "$env_bash_major" -ge "$min_version" ]]; then
        return 0
    else
        return 1
    fi
}

# Check if PATH fix is already in shell config
# Returns 0 if configured, 1 if not
_mt_is_bash_path_configured() {
    local bash_path="${1:-$METOOL_BASH_PATH}"
    
    if [[ -z "$bash_path" ]]; then
        return 1
    fi
    
    local bash_dir=$(dirname "$bash_path")
    local shell_config=""
    
    if [[ "$SHELL" == *"zsh" ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash" ]]; then
        shell_config="$HOME/.bashrc"
    fi
    
    if [[ -n "$shell_config" ]] && [[ -f "$shell_config" ]] && grep -q "$bash_dir" "$shell_config"; then
        return 0
    fi
    
    return 1
}

# Ensure bash is in PATH and shell RC
# Returns 0 if successful, 1 if not
_mt_ensure_bash_in_path() {
    local bash_path="${1:-$METOOL_BASH_PATH}"
    local interactive="${2:-true}"
    
    if [[ -z "$bash_path" ]]; then
        return 1
    fi
    
    local bash_dir=$(dirname "$bash_path")
    
    # Check if already in current PATH
    if [[ ":$PATH:" == *":$bash_dir:"* ]]; then
        return 0
    fi
    
    # Determine shell config file
    local shell_config=""
    if [[ "$SHELL" == *"zsh" ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash" ]]; then
        shell_config="$HOME/.bashrc"
    fi
    
    if [[ -z "$shell_config" ]]; then
        return 1
    fi
    
    # Check if already in shell config
    local in_config=false
    if [[ -f "$shell_config" ]] && grep -q "$bash_dir" "$shell_config"; then
        in_config=true
    fi
    
    # Add to shell config if not there
    if [[ "$in_config" == "false" ]]; then
        if [[ "$interactive" == "true" ]]; then
            echo "Modern bash found at $bash_path but not in PATH"
            read -p "Add to PATH in $shell_config? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
        
        echo "export PATH=\"$bash_dir:\$PATH\"" >> "$shell_config"
        echo "Added to $shell_config"
    fi
    
    # Source the config to update current session
    if [[ -f "$shell_config" ]]; then
        source "$shell_config" 2>/dev/null || true
        export PATH="$bash_dir:$PATH"
    fi
    
    return 0
}

# Install modern bash if needed (macOS with Homebrew)
# Returns 0 if successful or already installed, 1 if not
_mt_install_modern_bash() {
    local interactive="${1:-true}"
    
    # Check if already have modern bash
    if _mt_check_bash_version; then
        return 0
    fi
    
    # Check for Homebrew on macOS
    if [[ "$OSTYPE" != "darwin"* ]] || ! command -v brew &>/dev/null; then
        return 1
    fi
    
    if [[ "$interactive" == "true" ]]; then
        echo "Metool requires bash 4.0 or higher"
        read -p "Install modern bash with Homebrew? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    echo "Installing bash..."
    if brew install bash; then
        echo "✅ Modern bash installed successfully"
        # Update our variables
        _mt_check_bash_version
        return 0
    else
        echo "❌ Failed to install bash" >&2
        return 1
    fi
}

# Main function to ensure bash is properly configured
# This checks, installs if needed, and configures PATH
_mt_ensure_bash() {
    local interactive="${1:-true}"
    local auto_fix="${2:-false}"
    
    # Override interactive if auto_fix is true
    if [[ "$auto_fix" == "true" ]]; then
        interactive="false"
    fi
    
    # Check if we have modern bash installed
    if ! _mt_check_bash_version; then
        if [[ "$interactive" == "true" ]] || [[ "$auto_fix" == "true" ]]; then
            _mt_install_modern_bash "$interactive"
        else
            return 1
        fi
    fi
    
    # Ensure it's in PATH
    if ! _mt_check_env_bash; then
        _mt_ensure_bash_in_path "$METOOL_BASH_PATH" "$interactive"
    fi
    
    return 0
}