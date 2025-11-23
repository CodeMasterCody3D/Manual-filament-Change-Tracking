#!/bin/bash
# verify_install.sh - Verify tool change tracking installation
#
# This script validates that all required components are properly installed
# and have correct permissions.

set -u

# Color output helpers
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

ERRORS=0
WARNINGS=0

info() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    WARNINGS=$((WARNINGS + 1))
}

error() {
    echo -e "${RED}[FAIL]${NC} $*"
    ERRORS=$((ERRORS + 1))
}

# Check if a command exists
check_command() {
    local cmd="$1"
    local description="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local path
        path=$(command -v "$cmd")
        info "$description found at $path"
        
        # Check if executable
        if [ -x "$path" ]; then
            info "$description is executable"
        else
            error "$description is not executable"
        fi
        return 0
    else
        error "$description not found in PATH"
        return 1
    fi
}

# Check if a file exists and is executable
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        info "$description exists at $file"
        
        if [ -x "$file" ]; then
            info "$description is executable"
        else
            error "$description is not executable"
        fi
        return 0
    else
        error "$description not found at $file"
        return 1
    fi
}

# Test command execution
test_execution() {
    local cmd="$1"
    local args="$2"
    local description="$3"
    local expected_exit="${4:-0}"
    
    if eval "$cmd $args" >/dev/null 2>&1; then
        local exit_code=$?
        if [ "$exit_code" -eq "$expected_exit" ]; then
            info "$description executed successfully (exit code: $exit_code)"
            return 0
        else
            warn "$description exited with code $exit_code (expected $expected_exit)"
            return 1
        fi
    else
        local exit_code=$?
        if [ "$exit_code" -eq "$expected_exit" ]; then
            info "$description executed with expected exit code $exit_code"
            return 0
        else
            error "$description failed with exit code $exit_code"
            return 1
        fi
    fi
}

# Main verification
main() {
    echo "========================================="
    echo "Tool Change Tracking Installation Verification"
    echo "========================================="
    echo ""
    
    echo "Checking system dependencies..."
    check_command "python3" "Python 3"
    check_command "jq" "jq JSON processor"
    echo ""
    
    echo "Checking installed scripts..."
    
    # Try to find scripts in common locations
    local found_tracker=false
    local found_status=false
    local found_update=false
    
    for dir in . "$HOME" "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
        if [ -f "$dir/tool_change_tracker.py" ]; then
            check_file "$dir/tool_change_tracker.py" "tool_change_tracker.py"
            found_tracker=true
            
            # Test execution
            test_execution "$dir/tool_change_tracker.py" "--help" "tool_change_tracker.py --help"
            break
        fi
    done
    
    if [ "$found_tracker" = false ]; then
        error "tool_change_tracker.py not found in common locations"
    fi
    
    for dir in ./scripts "$HOME" "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
        if [ -f "$dir/get_tool_change_status.sh" ]; then
            check_file "$dir/get_tool_change_status.sh" "get_tool_change_status.sh"
            found_status=true
            
            # Test execution (expect exit 1 since no JSON file exists yet)
            test_execution "$dir/get_tool_change_status.sh" "--help" "get_tool_change_status.sh --help"
            break
        fi
    done
    
    if [ "$found_status" = false ]; then
        error "get_tool_change_status.sh not found in common locations"
    fi
    
    for dir in . "$HOME" "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
        if [ -f "$dir/update_tool_change.py" ]; then
            check_file "$dir/update_tool_change.py" "update_tool_change.py"
            found_update=true
            break
        fi
    done
    
    if [ "$found_update" = false ]; then
        warn "update_tool_change.py not found (may not be installed yet)"
    fi
    
    echo ""
    echo "Checking example files..."
    
    if [ -f "examples/dynamic_macro_m600.gcode" ]; then
        info "Example macro file exists"
    else
        warn "Example macro file not found (expected at examples/dynamic_macro_m600.gcode)"
    fi
    
    echo ""
    echo "========================================="
    echo "Verification Summary"
    echo "========================================="
    
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        info "All checks passed!"
        echo ""
        echo "Installation appears to be correct."
        echo "You can now configure your printer.cfg and OrcaSlicer."
        exit 0
    elif [ $ERRORS -eq 0 ]; then
        warn "Verification completed with $WARNINGS warning(s)"
        echo ""
        echo "Installation is mostly correct, but there are some warnings."
        echo "Please review the warnings above."
        exit 0
    else
        error "Verification failed with $ERRORS error(s) and $WARNINGS warning(s)"
        echo ""
        echo "Please fix the errors above before using the tool."
        exit 1
    fi
}

main "$@"
