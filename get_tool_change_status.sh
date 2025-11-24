#!/bin/bash
# Reads the current tool change progress from JSON and prints it.
set -euo pipefail

# Helper functions
error() {
    echo "$*" >&2
}

# Resolve the real user when running under sudo
get_real_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        echo "$SUDO_USER"
    else
        echo "${USER:-$(whoami)}"
    fi
}

# Get the home directory of the real user
get_real_home() {
    local real_user
    real_user=$(get_real_user)
    if [ -n "${SUDO_USER:-}" ]; then
        getent passwd "$real_user" | cut -d: -f6
    else
        echo "${HOME:-$(eval echo ~"$real_user")}"
    fi
}

# Resolve PRINTER_CONFIG_DIR
resolve_printer_config_dir() {
    # Priority 1: Environment variable
    if [ -n "${PRINTER_CONFIG_DIR:-}" ] && [ -d "$PRINTER_CONFIG_DIR" ]; then
        echo "$PRINTER_CONFIG_DIR"
        return 0
    fi
    
    # Priority 2: Check for .toolchange-config
    for dir in "." "${HOME}/printer_data/config"; do
        if [ -f "$dir/.toolchange-config" ]; then
            # shellcheck disable=SC1090
            if source "$dir/.toolchange-config" 2>/dev/null && [ -n "${PRINTER_CONFIG_DIR:-}" ]; then
                echo "$PRINTER_CONFIG_DIR"
                return 0
            fi
        fi
    done
    
    # Priority 3: Auto-scan
    local real_home
    real_home=$(get_real_home)
    
    if [ -d "$real_home/printer_data/config" ]; then
        echo "$real_home/printer_data/config"
        return 0
    fi
    
    for dir in "$real_home"/printer*; do
        if [ -d "$dir/printer_data/config" ]; then
            echo "$dir/printer_data/config"
            return 0
        fi
    done
    
    return 1
}

# Main logic
CONFIG_DIR=$(resolve_printer_config_dir) || {
    error "ERROR: Could not detect printer config directory."
    error "Please set PRINTER_CONFIG_DIR or run the installer."
    exit 1
}

JSON_FILE="$CONFIG_DIR/tool_changes.json"

if [ ! -f "$JSON_FILE" ]; then
    error "ERROR: No tool change data found."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    error "ERROR: jq is required but not installed"
    exit 2
fi

current_change=$(jq '.current_change' "$JSON_FILE")
total_changes=$(jq '.total_changes' "$JSON_FILE")

if [ "$current_change" -ge "$total_changes" ]; then
    echo "Tool changes completed."
    exit 0
fi

# Extract the tool number and color for the current change
tool_number=$(jq ".changes[$current_change].tool_number" "$JSON_FILE")
color=$(jq -r ".changes[$current_change].color" "$JSON_FILE")
line=$(jq ".changes[$current_change].line" "$JSON_FILE")
echo "Tool Change $((current_change + 1)) of $total_changes - $color (T$tool_number) at line $line"
