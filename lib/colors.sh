# Color codes for log levels
# Check if colors should be disabled
_mt_should_disable_colors() {
  # Disable colors if NO_COLOR is set (following NO_COLOR standard)
  [[ -n "${NO_COLOR:-}" ]] && return 0
  
  # Disable colors if not in a terminal
  [[ ! -t 1 ]] && return 0
  
  # Disable colors if TERM is dumb
  [[ "$TERM" == "dumb" ]] && return 0
  
  # Otherwise, use colors
  return 1
}

# Set color variables based on whether colors should be used
if _mt_should_disable_colors; then
  export MT_COLOR_ERROR=""
  export MT_COLOR_WARNING=""
  export MT_COLOR_INFO=""
  export MT_COLOR_DEBUG=""
  export MT_COLOR_RESET=""
else
  export MT_COLOR_ERROR="\033[0;31m"    # Red
  export MT_COLOR_WARNING="\033[0;33m"  # Yellow
  export MT_COLOR_INFO="\033[0;34m"     # Blue
  export MT_COLOR_DEBUG="\033[0;36m"    # Cyan
  export MT_COLOR_RESET="\033[0m"
fi
