#!/usr/bin/env bash
# Confirmation prompt functions for metool

# No color handling needed for prompts

# Single item confirmation prompt with abort option
# Usage: _mt_confirm "Message" [default]
# Returns: 0 for Yeah, 1 for Nah, 2 for Abort, 3 for Don't ask again
_mt_confirm() {
    local message="$1"
    local default="${2:-Yeah}"
    local response
    local don_t_ask_var="${MT_DONT_ASK_VAR:-MT_DONT_ASK}"
    
    # Check if the don't ask variable is set
    if [[ -n "${!don_t_ask_var}" ]]; then
        # If it's set to "yeah", always return success
        if [[ "${!don_t_ask_var}" == "yeah" ]]; then
            return 0
        # If it's set to "nah", always return failure
        elif [[ "${!don_t_ask_var}" == "nah" ]]; then
            return 1
        fi
    fi
    
    # Make the default option uppercase
    default_upper="${default^^}"
    
    # Prepare prompt options (no colors)
    local prompt_options="(Y)eah/(N)ah/(A)bort/(D)on't ask again [${default_upper}]:"
    
    # Show prompt and read response
    echo -e "$message"
    read -p "$prompt_options " response
    
    # Default if empty response
    response="${response:-$default}"
    
    # Process response
    case "${response,,}" in
        y|yeah)
            return 0
            ;;
        n|nah)
            return 1
            ;;
        a|abort)
            return 2
            ;;
        d|don\'t|dont)
            # Prompt for which value to remember
            echo "Remember which response?"
            read -p "(Y)eah/(N)ah/(C)ancel: " remember
            case "${remember,,}" in
                y|yeah)
                    export $don_t_ask_var="yeah"
                    _mt_info "Will automatically choose 'Yeah' for future prompts in this session"
                    return 0
                    ;;
                n|nah)
                    export $don_t_ask_var="nah"
                    _mt_info "Will automatically choose 'Nah' for future prompts in this session"
                    return 1
                    ;;
                *)
                    _mt_info "Will continue to ask for confirmation"
                    # Re-run the confirmation
                    _mt_confirm "$message" "$default"
                    return $?
                    ;;
            esac
            ;;
        *)
            # For any other response, use the default
            if [[ "${default,,}" == "yeah" ]]; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

# Multiple items confirmation prompt with quit option
# Usage: _mt_confirm_multiple "Message" [default]
# Returns: 0 for Yeah, 1 for Nah, 2 for All, 3 for Quit, 4 for Don't ask again
_mt_confirm_multiple() {
    local message="$1"
    local default="${2:-Yeah}"
    local response
    local don_t_ask_var="${MT_DONT_ASK_VAR:-MT_DONT_ASK}"
    
    # Check if the don't ask variable is set
    if [[ -n "${!don_t_ask_var}" ]]; then
        # If it's set to "yeah", always return success
        if [[ "${!don_t_ask_var}" == "yeah" ]]; then
            return 0
        # If it's set to "nah", always return failure
        elif [[ "${!don_t_ask_var}" == "nah" ]]; then
            return 1
        # If it's set to "all", always process all items
        elif [[ "${!don_t_ask_var}" == "all" ]]; then
            return 2
        fi
    fi
    
    # Make the default option uppercase
    default_upper="${default^^}"
    
    # Prepare prompt options (no colors)
    local prompt_options="(Y)eah/(N)ah/(A)ll/(Q)uit/(D)on't ask again [${default_upper}]:"
    
    # Show prompt and read single character response
    echo -e "$message"
    echo -n "$prompt_options "
    read -n1 -s response
    echo  # Add newline after character input
    
    # Default if empty response (shouldn't happen with -n1, but just in case)
    response="${response:-$default}"
    
    # Process response
    case "${response,,}" in
        y|yeah)
            return 0
            ;;
        n|nah)
            return 1
            ;;
        a|all)
            return 2
            ;;
        q|quit)
            return 3
            ;;
        d|don\'t|dont)
            # Prompt for which value to remember
            echo "Remember which response?"
            echo -n "(Y)eah/(N)ah/(A)ll/(C)ancel: "
            read -n1 -s remember
            echo  # Add newline after character input
            case "${remember,,}" in
                y|yeah)
                    export $don_t_ask_var="yeah"
                    _mt_info "Will automatically choose 'Yeah' for future prompts in this session"
                    return 0
                    ;;
                n|nah)
                    export $don_t_ask_var="nah"
                    _mt_info "Will automatically choose 'Nah' for future prompts in this session"
                    return 1
                    ;;
                a|all)
                    export $don_t_ask_var="all"
                    _mt_info "Will automatically choose 'All' for future prompts in this session"
                    return 2
                    ;;
                *)
                    _mt_info "Will continue to ask for confirmation"
                    # Re-run the confirmation
                    _mt_confirm_multiple "$message" "$default"
                    return $?
                    ;;
            esac
            ;;
        *)
            # For any other response, use the default
            if [[ "${default,,}" == "yeah" ]]; then
                return 0
            elif [[ "${default,,}" == "all" ]]; then
                return 2
            else
                return 1
            fi
            ;;
    esac
}

# Example usage function
_mt_prompt_example() {
    echo "Demonstration of confirmation prompts"
    
    # Single item confirmation
    _mt_confirm "Do you want to proceed with this action?"
    case $? in
        0) echo "User chose Yeah" ;;
        1) echo "User chose Nah" ;;
        2) echo "User chose Abort" ;;
        3) echo "User chose Don't ask again" ;;
    esac
    
    # Multiple items confirmation
    _mt_confirm_multiple "Process this item?"
    case $? in
        0) echo "User chose Yeah" ;;
        1) echo "User chose Nah" ;;
        2) echo "User chose All" ;;
        3) echo "User chose Quit" ;;
        4) echo "User chose Don't ask again" ;;
    esac
}