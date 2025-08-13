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
  export MT_COLOR_GREEN=""
  export MT_COLOR_RED=""
  export MT_COLOR_YELLOW=""
  export MT_COLOR_BLUE=""
  export MT_COLOR_PURPLE=""
  export MT_COLOR_CYAN=""
  export MT_COLOR_BOLD=""
  export MT_COLOR_DIM=""
else
  export MT_COLOR_ERROR="\033[0;31m"    # Red
  export MT_COLOR_WARNING="\033[0;33m"  # Yellow
  export MT_COLOR_INFO="\033[0;34m"     # Blue
  export MT_COLOR_DEBUG="\033[0;36m"    # Cyan
  export MT_COLOR_RESET="\033[0m"
  export MT_COLOR_GREEN="\033[0;32m"    # Green
  export MT_COLOR_RED="\033[0;31m"      # Red
  export MT_COLOR_YELLOW="\033[0;33m"   # Yellow
  export MT_COLOR_BLUE="\033[0;34m"     # Blue
  export MT_COLOR_PURPLE="\033[0;35m"   # Purple
  export MT_COLOR_CYAN="\033[0;36m"     # Cyan
  export MT_COLOR_BOLD="\033[1m"        # Bold
  export MT_COLOR_DIM="\033[2m"         # Dim
fi
