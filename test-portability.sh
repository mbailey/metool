#!/bin/bash
# Test script to verify metool test portability across different systems

echo "=== Metool Test Portability Check ==="
echo "Platform: $(uname -s)"
echo "Distribution: $(if [ -f /etc/os-release ]; then . /etc/os-release; echo "$NAME $VERSION"; else echo "Unknown"; fi)"
echo ""

# Check for required commands
echo "=== Checking Dependencies ==="
commands=(
    "bats:bats-core"
    "realpath:coreutils"
    "readlink:coreutils"
    "ln:coreutils"
    "stow:stow"
    "find:findutils"
    "grep:grep"
)

missing=0
for cmd_pkg in "${commands[@]}"; do
    cmd="${cmd_pkg%%:*}"
    pkg="${cmd_pkg#*:}"
    if command -v "$cmd" &>/dev/null; then
        echo "✅ $cmd: $(command -v "$cmd")"
        
        # Check for GNU vs BSD variants
        case "$cmd" in
            ln)
                if command ln --help 2>&1 | grep -q -- --relative; then
                    echo "   └─ GNU ln (supports --relative)"
                else
                    echo "   └─ BSD ln (no --relative support)"
                fi
                ;;
            find)
                if command find --version 2>&1 | grep -q GNU; then
                    echo "   └─ GNU find"
                else
                    echo "   └─ BSD find"
                fi
                ;;
            readlink)
                if command readlink --version 2>&1 | grep -q GNU; then
                    echo "   └─ GNU readlink"
                else
                    echo "   └─ BSD readlink"
                fi
                ;;
        esac
    else
        echo "❌ $cmd: NOT FOUND (install package: $pkg)"
        missing=$((missing + 1))
    fi
done

echo ""
echo "=== Path Normalization Test ==="
# Test the specific macOS issue
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/test"
touch "$tmpdir/test/file"

# Test if we have the /private prefix issue
if [ -d "/private" ] && [ "$(uname -s)" = "Darwin" ]; then
    echo "macOS detected - testing /private prefix handling:"
    echo "  Temp dir: $tmpdir"
    echo "  Realpath: $(realpath "$tmpdir")"
    if [ "$tmpdir" != "$(realpath "$tmpdir")" ]; then
        echo "  ⚠️  Path normalization needed (paths differ)"
    else
        echo "  ✅ Paths match"
    fi
else
    echo "Non-macOS system - no /private prefix issue expected"
fi

rm -rf "$tmpdir"

echo ""
if [ $missing -eq 0 ]; then
    echo "✅ All dependencies found - tests should be portable!"
else
    echo "❌ Missing $missing dependencies - tests may fail"
fi