#!/usr/bin/env bats

# Source the helper script
load test_helper

setup() {
  # Set up test environment
  export MT_ROOT="${BATS_TEST_DIRNAME}/.."
  export MT_LOG_LEVEL="ERROR"
  
  # Source the deps library
  source "${MT_ROOT}/lib/deps.sh"
  
  # Mock _mt_error function
  _mt_error() { echo "ERROR: $*" >&2; }
  _mt_debug() { echo "DEBUG: $*"; }
  _mt_log() { echo "$@" >&2; }
}

@test "_mt_deps shows usage with invalid argument" {
  run _mt_deps --invalid
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: mt deps [--install]" ]]
  [[ "$output" =~ "--install    Offer to install missing dependencies" ]]
}

@test "_mt_deps runs dependency check without arguments" {
  run _mt_deps
  
  # Should always show header
  [[ "$output" =~ "Checking metool dependencies..." ]]
  
  # Should check for realpath
  [[ "$output" =~ "realpath:" ]]
  
  # Should check for stow
  [[ "$output" =~ "stow:" ]]
  
  # Should have a summary section
  [[ "$output" =~ "All required dependencies found!" ]] || [[ "$output" =~ "Missing required dependencies:" ]]
}

@test "_mt_check_deps detects realpath" {
  if ! command -v realpath &>/dev/null; then
    skip "realpath not available for testing"
  fi
  
  run _mt_check_deps
  
  [[ "$output" =~ "✅ realpath: Found at" ]]
}

@test "_mt_check_deps detects stow" {
  if ! command -v stow &>/dev/null; then
    skip "stow not available for testing"
  fi
  
  run _mt_check_deps
  
  [[ "$output" =~ "✅ stow: Found at" ]]
}

@test "_mt_check_deps detects bash-completion" {
  # This test checks if bash-completion detection works
  run _mt_check_deps
  
  # Should mention bash-completion in output
  [[ "$output" =~ "bash-completion:" ]]
}

@test "_mt_check_deps detects bats" {
  # We know bats is installed since we're running in it
  run _mt_check_deps
  
  [[ "$output" =~ "✅ bats: Found at" ]]
}

@test "_mt_check_deps returns success when all required deps found" {
  # Mock command to simulate all deps present
  command() {
    case "$1" in
      -v)
        case "$2" in
          realpath|stow|gln|bats) return 0 ;;
          *) builtin command "$@" ;;
        esac
        ;;
      *) builtin command "$@" ;;
    esac
  }
  
  run _mt_check_deps
  
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅ All required dependencies found!" ]]
}

@test "_mt_check_deps returns failure when required deps missing" {
  # Mock command to simulate missing realpath
  command() {
    case "$1" in
      -v)
        case "$2" in
          realpath) return 1 ;;
          *) builtin command "$@" ;;
        esac
        ;;
      *) builtin command "$@" ;;
    esac
  }
  
  run _mt_check_deps
  
  [ "$status" -eq 1 ]
  [[ "$output" =~ "❌ realpath: Not found" ]]
  [[ "$output" =~ "❌ Missing required dependencies:" ]]
}

@test "_mt_deps with --install detects Homebrew on macOS" {
  # Skip if not on macOS
  if [[ "$OSTYPE" != "darwin"* ]]; then
    skip "Test requires macOS"
  fi
  
  # Only test that --install flag is recognized
  # Don't test the actual install process as it requires mocking too much
  run _mt_deps --install </dev/null
  
  # Should either offer to install or say all deps are installed
  [[ "$output" =~ "Checking metool dependencies" ]]
  
  # If Homebrew is available and deps are missing, should mention it
  if command -v brew &>/dev/null && [[ "$output" =~ "Missing required dependencies" ]]; then
    [[ "$output" =~ "Homebrew" ]]
  fi
}

@test "_mt_deps --install fails gracefully without Homebrew" {
  # Mock brew not found
  command() {
    case "$1" in
      -v)
        case "$2" in
          brew) return 1 ;;
          realpath) return 1 ;;  # Ensure we have missing deps
          *) builtin command "$@" ;;
        esac
        ;;
      *) builtin command "$@" ;;
    esac
  }
  
  run _mt_deps --install
  
  [[ "$output" =~ "❌ --install flag requires Homebrew" ]]
  [[ "$output" =~ "Please install Homebrew first" ]]
}