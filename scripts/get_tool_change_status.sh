#!/bin/bash
# get_tool_change_status.sh - Read and display tool change progress from JSON data
#
# This script reads tool change tracking data and displays the current status.
# It supports multiple output formats and installation locations.

set -e
set -u

# Default configuration
JSON_FILE="${JSON_FILE:-/tmp/tool_change_data.json}"
OUTPUT_JSON=false

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
    --json              Output in machine-readable JSON format
    --install-dir DIR   Override install directory location
    --help, -h          Show this help message

ENVIRONMENT:
    INSTALL_DIR         Directory where related scripts are installed
    JSON_FILE           Path to JSON data file (default: /tmp/tool_change_data.json)

EXIT CODES:
    0   Success
    1   JSON file not found
    2   Invalid JSON or jq error
    3   Invalid arguments

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --json
    $(basename "$0") --install-dir /usr/local/bin

EOF
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --json)
                OUTPUT_JSON=true
                shift
                ;;
            --install-dir)
                if [ -z "${2:-}" ]; then
                    echo "ERROR: --install-dir requires an argument" >&2
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
                echo "ERROR: Unknown argument: $1" >&2
                usage
                exit 3
                ;;
        esac
    done
}

# Main logic
main() {
    parse_args "$@"
    
    # Validate JSON file exists
    if [ ! -f "$JSON_FILE" ]; then
        if [ "$OUTPUT_JSON" = true ]; then
            echo '{"error": "No tool change data found", "file": "'"$JSON_FILE"'"}'
        else
            echo "ERROR: No tool change data found at $JSON_FILE" >&2
        fi
        exit 1
    fi
    
    # Validate jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq is required but not installed" >&2
        exit 2
    fi
    
    # Read and validate JSON
    if ! current_change=$(jq -e '.current_change' "$JSON_FILE" 2>/dev/null); then
        echo "ERROR: Invalid JSON or missing 'current_change' field" >&2
        exit 2
    fi
    
    if ! total_changes=$(jq -e '.total_changes' "$JSON_FILE" 2>/dev/null); then
        echo "ERROR: Invalid JSON or missing 'total_changes' field" >&2
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
        echo "ERROR: Failed to read tool number from JSON" >&2
        exit 2
    fi
    
    color=$(jq -r ".changes[$current_change].color" "$JSON_FILE" 2>/dev/null || echo "Unknown")
    brand=$(jq -r ".changes[$current_change].brand" "$JSON_FILE" 2>/dev/null || echo "")
    material=$(jq -r ".changes[$current_change].material" "$JSON_FILE" 2>/dev/null || echo "")
    line=$(jq -e ".changes[$current_change].line" "$JSON_FILE" 2>/dev/null || echo "0")
    
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
