#!/usr/bin/env bash
# get_tool_change_status.sh - Read and display tool change progress from JSON data
#
# This script reads tool change tracking data and displays the current status.
# It supports multiple output formats and installation locations.

set -euo pipefail

# Default configuration
JSON_FILE="${JSON_FILE:-}"
OUTPUT_JSON=false

# Helper functions
info() {
    echo "$*"
}

warn() {
    echo "$*" >&2
}

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

# Detect printer directories in user's home
detect_printer_config_dirs() {
    local target_home="$1"
    local candidates=()
    
    # Find immediate child directories that contain printer_data/config or config
    if [ -d "$target_home" ]; then
        while IFS= read -r -d '' dir; do
            local basename
            basename=$(basename "$dir")
            local config_path=""
            
            # Determine config path based on what exists
            if [ -d "$dir/printer_data/config" ]; then
                config_path="$dir/printer_data/config"
            elif [ -d "$dir/config" ]; then
                config_path="$dir/config"
            fi
            
            # Add if basename starts with "printer" OR we found a config path
            if [[ "$basename" == printer* ]] || [ -n "$config_path" ]; then
                if [ -n "$config_path" ]; then
                    candidates+=("$config_path")
                fi
            fi
        done < <(find "$target_home" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null || true)
    fi
    
    # Return unique candidates
    printf '%s\n' "${candidates[@]}" 2>/dev/null | sort -u || true
}

# Resolve PRINTER_CONFIG_DIR with fallback
resolve_printer_config_dir() {
    # Priority 1: Environment variable
    if [ -n "${PRINTER_CONFIG_DIR:-}" ]; then
        if [ -d "$PRINTER_CONFIG_DIR" ]; then
            echo "$PRINTER_CONFIG_DIR"
            return 0
        fi
    fi
    
    # Priority 2: Check for .toolchange-config in current directory or common locations
    local config_file=""
    for dir in "${PRINTER_CONFIG_DIR:-}" "." "$HOME/printer_data/config" "$HOME/.config/toolchange"; do
        if [ -n "$dir" ] && [ -f "$dir/.toolchange-config" ]; then
            config_file="$dir/.toolchange-config"
            break
        fi
    done
    
    if [ -n "$config_file" ]; then
        # Source the config file to get PRINTER_CONFIG_DIR
        # shellcheck disable=SC1090
        if source "$config_file" 2>/dev/null && [ -n "${PRINTER_CONFIG_DIR:-}" ]; then
            echo "$PRINTER_CONFIG_DIR"
            return 0
        fi
    fi
    
    # Priority 3: Auto-scan home directory
    local real_home
    real_home=$(get_real_home)
    local candidates
    mapfile -t candidates < <(detect_printer_config_dirs "$real_home")
    
    if [ ${#candidates[@]} -gt 0 ]; then
        # Use the first match
        echo "${candidates[0]}"
        return 0
    fi
    
    # No printer config directory found
    return 1
}

# Detect install directory for related scripts
# Checks common locations in order of preference
detect_install_dir() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Priority order: script's own directory, env var, common locations
    local search_paths=(
        "$script_dir"
        "${INSTALL_DIR:-}"
        "$HOME/.local/bin"
        "/usr/local/bin"
        "/opt/toolchange/bin"
        "."
    )
    
    for path in "${search_paths[@]}"; do
        if [ -n "$path" ] && [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Fallback to current directory
    echo "."
}

INSTALL_DIR="${INSTALL_DIR:-$(detect_install_dir)}"

# Usage information
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Read and display current tool change progress from tracking data.

OPTIONS:
    --json [FILE]       Output in machine-readable JSON format
                        Optionally specify JSON file path (default: auto-detected)
    --install-dir DIR   Override install directory location (deprecated)
    --help, -h          Show this help message

ENVIRONMENT:
    PRINTER_CONFIG_DIR  Directory containing printer config and tool_changes.json
    INSTALL_DIR         Directory where related scripts are installed (deprecated)
    JSON_FILE           Path to JSON data file (deprecated, use --json FILE)

CONFIGURATION:
    The script looks for PRINTER_CONFIG_DIR in the following order:
    1. PRINTER_CONFIG_DIR environment variable
    2. .toolchange-config file in current or common directories
    3. Auto-scan home directory for printer_data/config directories

EXIT CODES:
    0   Success
    1   JSON file not found or printer config not detected
    2   Invalid JSON or jq error
    3   Invalid arguments

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --json
    $(basename "$0") --json /path/to/tool_changes.json
    PRINTER_CONFIG_DIR=/home/user/printer_ender5/printer_data/config $(basename "$0")

EOF
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --json)
                OUTPUT_JSON=true
                # Check if next argument is a file path
                if [ $# -gt 1 ] && [[ ! "$2" =~ ^-- ]]; then
                    JSON_FILE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --install-dir)
                if [ -z "${2:-}" ]; then
                    error "ERROR: --install-dir requires an argument"
                    exit 3
                fi
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error "ERROR: Unknown argument: $1"
                usage
                exit 3
                ;;
        esac
    done
}

# Write color_prompt.cfg with current tool change info
write_color_prompt_cfg() {
    local config_dir="$1"
    local current_change="$2"
    local total_changes="$3"
    local color="${4:-Unknown}"
    local material="${5:-Unknown}"
    local brand="${6:-Unknown}"
    
    local cfg_file="$config_dir/color_prompt.cfg"
    local progress=$((current_change + 1))
    
    # Create the Klipper macro
    cat > "$cfg_file" <<EOF
# Auto-generated by get_tool_change_status.sh
# This file is overwritten on every status check

[gcode_macro TOOL_CHANGE_STATUS]
description: Display current tool change status
variable_current_change: $current_change
variable_total_changes: $total_changes
variable_progress: $progress
variable_color: "$color"
variable_material: "$material"
variable_brand: "$brand"
gcode:
    {% set status = printer["gcode_macro TOOL_CHANGE_STATUS"] %}
    RESPOND MSG="Tool Change {status.progress} of {status.total_changes}: {status.color} ({status.brand} {status.material})"
EOF
    
    # Set ownership if running as sudo
    if [ -n "${SUDO_USER:-}" ]; then
        local real_user
        real_user=$(get_real_user)
        chown "$real_user:$real_user" "$cfg_file" 2>/dev/null || true
    fi
    
    return 0
}

# Main logic
main() {
    parse_args "$@"
    
    # Resolve PRINTER_CONFIG_DIR
    local config_dir
    if ! config_dir=$(resolve_printer_config_dir); then
        error "ERROR: Could not detect printer config directory."
        error "Please set PRINTER_CONFIG_DIR environment variable or run the installer."
        error ""
        error "Example:"
        error "  export PRINTER_CONFIG_DIR=\$HOME/printer_ender5/printer_data/config"
        error "  $0"
        exit 1
    fi
    
    # Determine JSON file path
    if [ -z "$JSON_FILE" ]; then
        # Source .toolchange-config if available to get TOOL_CHANGES_JSON
        if [ -f "$config_dir/.toolchange-config" ]; then
            # shellcheck disable=SC1090
            source "$config_dir/.toolchange-config" 2>/dev/null || true
        fi
        JSON_FILE="$config_dir/${TOOL_CHANGES_JSON:-tool_changes.json}"
    fi
    
    # Validate JSON file exists
    if [ ! -f "$JSON_FILE" ]; then
        if [ "$OUTPUT_JSON" = true ]; then
            echo '{"error": "No tool change data found", "file": "'"$JSON_FILE"'"}'
        else
            error "ERROR: No tool change data found at $JSON_FILE"
        fi
        exit 1
    fi
    
    # Validate jq is available
    if ! command -v jq >/dev/null 2>&1; then
        error "ERROR: jq is required but not installed"
        exit 2
    fi
    
    # Read and validate JSON
    if ! current_change=$(jq -e '.current_change' "$JSON_FILE" 2>/dev/null); then
        error "ERROR: Invalid JSON or missing 'current_change' field"
        exit 2
    fi
    
    if ! total_changes=$(jq -e '.total_changes' "$JSON_FILE" 2>/dev/null); then
        error "ERROR: Invalid JSON or missing 'total_changes' field"
        exit 2
    fi
    
    # Check if all changes are completed
    if [ "$current_change" -ge "$total_changes" ]; then
        if [ "$OUTPUT_JSON" = true ]; then
            echo '{"status": "completed", "current_change": '"$current_change"', "total_changes": '"$total_changes"'}'
        else
            echo "Tool changes completed."
        fi
        exit 0
    fi
    
    # Extract current change details
    if ! tool_number=$(jq -e ".changes[$current_change].tool_number" "$JSON_FILE" 2>/dev/null); then
        error "ERROR: Failed to read tool number from JSON"
        exit 2
    fi
    
    color=$(jq -r ".changes[$current_change].color" "$JSON_FILE" 2>/dev/null || echo "Unknown")
    brand=$(jq -r ".changes[$current_change].brand" "$JSON_FILE" 2>/dev/null || echo "")
    material=$(jq -r ".changes[$current_change].material" "$JSON_FILE" 2>/dev/null || echo "")
    line=$(jq -e ".changes[$current_change].line" "$JSON_FILE" 2>/dev/null || echo "0")
    
    # Always write color_prompt.cfg
    write_color_prompt_cfg "$config_dir" "$current_change" "$total_changes" "$color" "$material" "$brand"
    
    # Format output
    if [ "$OUTPUT_JSON" = true ]; then
        jq -n \
            --argjson current "$current_change" \
            --argjson total "$total_changes" \
            --argjson tool "$tool_number" \
            --arg color "$color" \
            --arg brand "$brand" \
            --arg material "$material" \
            --argjson line "$line" \
            '{
                status: "in_progress",
                current_change: $current,
                total_changes: $total,
                progress: ($current + 1),
                tool_number: $tool,
                color: $color,
                brand: $brand,
                material: $material,
                line: $line
            }'
    else
        local change_num=$((current_change + 1))
        local filament_desc="$color"
        if [ -n "$brand" ] && [ "$brand" != "Unknown" ]; then
            filament_desc="$filament_desc ($brand $material)"
        fi
        echo "Tool Change $change_num of $total_changes - $filament_desc (T$tool_number) at line $line"
    fi
    
    exit 0
}

# Run main function
main "$@"
