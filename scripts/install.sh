#!/bin/bash
# install.sh - Interactive installer for Manual Filament Change Tracking tools
#
# This script installs the tool change tracking utilities to a chosen directory.

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_INSTALL_DIR="/usr/local/bin"
NONINTERACTIVE=false
PRINTER_CONFIG_DIR=""
TARGET_ROOT=""

# Files to install
INSTALL_FILES=(
    "tool_change_tracker.py"
    "update_tool_change.py"
    "scripts/get_tool_change_status.sh"
)

# Per-printer files (installed to PRINTER_CONFIG_DIR)
PER_PRINTER_FILES=(
    "scripts/get_tool_change_status.sh"
    "tool_change_tracker.py"
    "update_tool_change.py"
)

# Color output helpers
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
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
        # Use getent to get the home directory
        getent passwd "$real_user" | cut -d: -f6
    else
        echo "$HOME"
    fi
}

# Detect printer directories in user's home
detect_printer_dirs() {
    local target_home="$1"
    local candidates=()
    
    # Check if $target_home itself contains printer_data/config
    if [ -d "$target_home/printer_data/config" ] || [ -d "$target_home/printer_data" ]; then
        candidates+=("$target_home")
    fi
    
    # Find immediate child directories starting with "printer"
    if [ -d "$target_home" ]; then
        while IFS= read -r -d '' dir; do
            local basename
            basename=$(basename "$dir")
            if [[ "$basename" == printer* ]]; then
                candidates+=("$dir")
            fi
        done < <(find "$target_home" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null || true)
        
        # Also find directories containing printer_data/config (non-printer* names)
        while IFS= read -r -d '' dir; do
            if [ -d "$dir/printer_data/config" ]; then
                local basename
                basename=$(basename "$dir")
                # Only add if not already in candidates and doesn't start with "printer"
                if [[ ! "$basename" == printer* ]]; then
                    local already_added=false
                    for candidate in "${candidates[@]}"; do
                        if [ "$candidate" = "$dir" ]; then
                            already_added=true
                            break
                        fi
                    done
                    if [ "$already_added" = false ]; then
                        candidates+=("$dir")
                    fi
                fi
            fi
        done < <(find "$target_home" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null || true)
    fi
    
    # Return unique candidates
    printf '%s\n' "${candidates[@]}" | sort -u
}

# Usage information
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Interactive installer for Manual Filament Change Tracking tools.

OPTIONS:
    --install-dir DIR   Install to specified directory (default: $DEFAULT_INSTALL_DIR)
    --yes, -y           Non-interactive mode, assume yes to prompts
    --help, -h          Show this help message

DESCRIPTION:
    This script installs the tool change tracking utilities to your chosen
    directory. By default, it runs interactively and will prompt for confirmation.

    The following files will be installed:
$(printf '        - %s\n' "${INSTALL_FILES[@]}")

EXAMPLES:
    $(basename "$0")                           # Interactive installation
    $(basename "$0") --yes                     # Non-interactive, use defaults
    $(basename "$0") --install-dir ~/bin       # Install to custom directory

EOF
}

# Parse command line arguments
parse_args() {
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --install-dir)
                if [ -z "${2:-}" ]; then
                    error "--install-dir requires an argument"
                    exit 1
                fi
                INSTALL_DIR="$2"
                shift 2
                ;;
            --yes|-y)
                NONINTERACTIVE=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Prompt for user confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$NONINTERACTIVE" = true ]; then
        return 0
    fi
    
    local response
    if [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n] " response
        response=${response:-y}
    else
        read -r -p "$prompt [y/N] " response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Prompt user to select a printer directory
select_printer_dir() {
    local target_home="$1"
    local candidates
    mapfile -t candidates < <(detect_printer_dirs "$target_home")
    
    echo "" >&2
    echo "=========================================" >&2
    echo "Select Printer Installation Target" >&2
    echo "=========================================" >&2
    echo "" >&2
    
    if [ ${#candidates[@]} -eq 0 ]; then
        info "No existing printer directories detected in $target_home"
        info "Will create new printer_data directory under $target_home"
        echo "0) Create new printer_data under $target_home" >&2
        echo "" >&2
        
        if [ "$NONINTERACTIVE" = true ]; then
            echo "0"
            return 0
        fi
        
        read -r -p "Press Enter to continue with option 0: " choice
        echo "0"
        return 0
    fi
    
    # Display options
    echo "Detected printer directories:" >&2
    echo "0) Create new printer_data under $target_home" >&2
    
    local i=1
    for dir in "${candidates[@]}"; do
        local display_name
        if [ "$dir" = "$target_home" ]; then
            display_name="$dir (root)"
        else
            display_name="$dir"
        fi
        echo "$i) $display_name" >&2
        i=$((i + 1))
    done
    echo "" >&2
    
    # Determine default selection
    local default_choice=1
    if [ ${#candidates[@]} -gt 0 ]; then
        default_choice=1
    else
        default_choice=0
    fi
    
    if [ "$NONINTERACTIVE" = true ]; then
        echo "$default_choice"
        return 0
    fi
    
    # Get user selection
    local choice
    read -r -p "Select printer target [$default_choice]: " choice
    choice=${choice:-$default_choice}
    
    # Validate selection
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        error "Invalid selection: $choice"
        exit 1
    fi
    
    if [ "$choice" -lt 0 ] || [ "$choice" -gt ${#candidates[@]} ]; then
        error "Selection out of range: $choice"
        exit 1
    fi
    
    echo "$choice"
}

# Check if we have write permission to install directory
check_permissions() {
    local dir="$1"
    
    if [ -d "$dir" ]; then
        if [ -w "$dir" ]; then
            return 0
        else
            return 1
        fi
    else
        # Check parent directory
        local parent
        parent="$(dirname "$dir")"
        if [ -w "$parent" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Validate install directory
validate_install_dir() {
    local dir="$1"
    
    # Expand tilde
    dir="${dir/#\~/$HOME}"
    
    # Create directory if it doesn't exist
    if [ ! -d "$dir" ]; then
        echo "[INFO] Directory $dir does not exist." >&2
        if confirm "Create it?"; then
            if ! mkdir -p "$dir"; then
                error "Failed to create directory $dir"
                exit 1
            fi
            echo "[INFO] Created directory $dir" >&2
        else
            error "Installation cancelled"
            exit 1
        fi
    fi
    
    # Check permissions
    if ! check_permissions "$dir"; then
        warn "You don't have write permission to $dir"
        warn "You may need to run this script with sudo or choose a different directory."
        if ! confirm "Continue anyway? (installation will likely fail)"; then
            exit 1
        fi
    fi
    
    echo "$dir"
}

# Install a single file
install_file() {
    local src="$1"
    local dest="$2"
    local filename
    filename="$(basename "$src")"
    
    local full_dest="$dest/$filename"
    
    # Check if file already exists
    if [ -f "$full_dest" ]; then
        warn "File $full_dest already exists"
        if ! confirm "Overwrite it?" "n"; then
            info "Skipping $filename"
            return 0
        fi
    fi
    
    # Copy file
    if cp "$src" "$full_dest"; then
        info "Installed $filename to $dest"
    else
        error "Failed to install $filename"
        return 1
    fi
    
    # Make executable
    if chmod +x "$full_dest"; then
        info "Made $filename executable"
    else
        warn "Failed to make $filename executable"
    fi
    
    return 0
}

# Create .toolchange-config file
create_toolchange_config() {
    local config_dir="$1"
    local config_file="$config_dir/.toolchange-config"
    local json_file="${2:-tool_changes.json}"
    
    info "Creating configuration file: $config_file"
    
    cat > "$config_file" <<EOF
# Tool Change Tracker Configuration
# This file is auto-generated by the installer

PRINTER_CONFIG_DIR="$config_dir"
TOOL_CHANGES_JSON="$json_file"
EOF
    
    if [ -n "${SUDO_USER:-}" ]; then
        local real_user
        real_user=$(get_real_user)
        chown "$real_user:$real_user" "$config_file"
    fi
    
    info "Created: $config_file"
}

# Install per-printer files to PRINTER_CONFIG_DIR
install_per_printer_files() {
    local config_dir="$1"
    local real_user
    real_user=$(get_real_user)
    
    info "Installing per-printer files to: $config_dir"
    echo ""
    
    for file in "${PER_PRINTER_FILES[@]}"; do
        local src_path="$REPO_ROOT/$file"
        local filename
        filename="$(basename "$file")"
        local dest_path="$config_dir/$filename"
        
        if [ ! -f "$src_path" ]; then
            error "Source file not found: $src_path"
            continue
        fi
        
        # Always overwrite if --yes or user confirmed
        if [ "$NONINTERACTIVE" = true ] || confirm "Install $filename to $config_dir?" "y"; then
            if cp "$src_path" "$dest_path"; then
                info "  $src_path -> $dest_path"
                chmod +x "$dest_path"
                
                # Set ownership if running as sudo
                if [ -n "${SUDO_USER:-}" ]; then
                    chown "$real_user:$real_user" "$dest_path"
                fi
            else
                error "Failed to copy $filename"
            fi
        else
            info "Skipped: $filename"
        fi
    done
    
    echo ""
}

# Create wrapper scripts for per-printer tools
create_wrapper_scripts() {
    local config_dir="$1"
    local wrapper_dir="$2"
    local printer_name="$3"
    local real_user
    real_user=$(get_real_user)
    
    # Ensure wrapper directory exists
    if [ ! -d "$wrapper_dir" ]; then
        mkdir -p "$wrapper_dir"
        if [ -n "${SUDO_USER:-}" ]; then
            chown "$real_user:$real_user" "$wrapper_dir"
        fi
    fi
    
    info "Creating wrapper scripts in: $wrapper_dir"
    
    # Create get_tool_change_status wrapper
    local status_wrapper="$wrapper_dir/get_tool_change_status-$printer_name"
    cat > "$status_wrapper" <<EOF
#!/bin/bash
# Wrapper script for $printer_name
export PRINTER_CONFIG_DIR="$config_dir"
exec "$config_dir/get_tool_change_status.sh" "\$@"
EOF
    chmod +x "$status_wrapper"
    if [ -n "${SUDO_USER:-}" ]; then
        chown "$real_user:$real_user" "$status_wrapper"
    fi
    info "Created: $status_wrapper"
    
    # Create tool_change_tracker wrapper
    local tracker_wrapper="$wrapper_dir/tool_change_tracker-$printer_name"
    cat > "$tracker_wrapper" <<EOF
#!/bin/bash
# Wrapper script for $printer_name
export PRINTER_CONFIG_DIR="$config_dir"
exec "$config_dir/tool_change_tracker.py" "\$@"
EOF
    chmod +x "$tracker_wrapper"
    if [ -n "${SUDO_USER:-}" ]; then
        chown "$real_user:$real_user" "$tracker_wrapper"
    fi
    info "Created: $tracker_wrapper"
}

# Main installation logic
main() {
    parse_args "$@"
    
    echo "========================================="
    echo "Manual Filament Change Tracking Installer"
    echo "========================================="
    echo ""
    
    # Resolve real user and home directory
    local real_user real_home
    real_user=$(get_real_user)
    real_home=$(get_real_home)
    
    info "Running as user: $real_user"
    info "Target home: $real_home"
    echo ""
    
    # Determine printer configuration directory
    if [ -n "${INSTALL_DIR:-}" ] && [ "$INSTALL_DIR" != "$DEFAULT_INSTALL_DIR" ]; then
        # Check if INSTALL_DIR looks like a printer config dir
        if [[ "$INSTALL_DIR" == *"/printer_data/config"* ]] || [[ "$INSTALL_DIR" == *"/printer_data"* ]]; then
            # Use as PRINTER_CONFIG_DIR
            TARGET_ROOT=$(dirname "$(dirname "$INSTALL_DIR")")
            PRINTER_CONFIG_DIR="$INSTALL_DIR"
            if [[ ! "$PRINTER_CONFIG_DIR" == *"/config" ]]; then
                PRINTER_CONFIG_DIR="$PRINTER_CONFIG_DIR/config"
            fi
            info "Using specified printer config directory: $PRINTER_CONFIG_DIR"
        else
            # INSTALL_DIR is for wrapper scripts, still need to select printer
            info "Install directory for wrappers: $INSTALL_DIR"
        fi
    fi
    
    # If PRINTER_CONFIG_DIR not yet determined, prompt user
    if [ -z "$PRINTER_CONFIG_DIR" ]; then
        local selection
        selection=$(select_printer_dir "$real_home")
        
        local candidates
        mapfile -t candidates < <(detect_printer_dirs "$real_home")
        
        if [ "$selection" -eq 0 ]; then
            # Create new printer_data under home
            TARGET_ROOT="$real_home"
            PRINTER_CONFIG_DIR="$real_home/printer_data/config"
            info "Will create new printer_data at: $TARGET_ROOT"
        else
            # Use selected existing directory
            TARGET_ROOT="${candidates[$((selection - 1))]}"
            PRINTER_CONFIG_DIR="$TARGET_ROOT/printer_data/config"
            info "Selected printer: $TARGET_ROOT"
        fi
    fi
    
    # Ensure PRINTER_CONFIG_DIR exists
    if [ ! -d "$PRINTER_CONFIG_DIR" ]; then
        info "Creating printer config directory: $PRINTER_CONFIG_DIR"
        if ! mkdir -p "$PRINTER_CONFIG_DIR"; then
            error "Failed to create $PRINTER_CONFIG_DIR"
            exit 1
        fi
        # Set ownership if running as sudo
        if [ -n "${SUDO_USER:-}" ]; then
            chown -R "$real_user:$real_user" "$TARGET_ROOT/printer_data"
        fi
    fi
    
    info "Printer config directory: $PRINTER_CONFIG_DIR"
    echo ""
    
    # Validate and prepare install directory (if different from PRINTER_CONFIG_DIR) 
    # This is now optional - we install to PRINTER_CONFIG_DIR by default
    if [ -n "${INSTALL_DIR:-}" ] && [ "$INSTALL_DIR" != "$PRINTER_CONFIG_DIR" ] && [ "$INSTALL_DIR" != "$DEFAULT_INSTALL_DIR" ]; then
        INSTALL_DIR=$(validate_install_dir "$INSTALL_DIR")
        info "Install directory for additional copies: $INSTALL_DIR"
    else
        INSTALL_DIR=""
    fi
    
    # Show what will be installed
    info "Per-printer files to be installed in $PRINTER_CONFIG_DIR:"
    for file in "${PER_PRINTER_FILES[@]}"; do
        echo "    - $(basename "$file")"
    done
    echo ""
    
    # Confirm installation
    if ! confirm "Proceed with installation?" "y"; then
        info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    info "Installing per-printer files..."
    echo ""
    
    # Install per-printer files
    install_per_printer_files "$PRINTER_CONFIG_DIR"
    
    # Create .toolchange-config
    create_toolchange_config "$PRINTER_CONFIG_DIR" "tool_changes.json"
    echo ""
    
    # Ask about wrapper scripts
    local install_wrappers=false
    local wrapper_dir="$real_home/.local/bin"
    
    if [ "$NONINTERACTIVE" = false ]; then
        if confirm "Install wrapper scripts to ~/.local/bin for easier access?" "y"; then
            install_wrappers=true
        fi
    else
        install_wrappers=true
    fi
    
    if [ "$install_wrappers" = true ]; then
        # Extract printer name from TARGET_ROOT
        local printer_name
        printer_name=$(basename "$TARGET_ROOT")
        if [ "$printer_name" = "$(basename "$real_home")" ]; then
            printer_name="default"
        fi
        
        create_wrapper_scripts "$PRINTER_CONFIG_DIR" "$wrapper_dir" "$printer_name"
        echo ""
        
        # Check if wrapper_dir is in PATH
        if [[ ":$PATH:" != *":$wrapper_dir:"* ]]; then
            warn "Note: $wrapper_dir is not in your PATH"
            info "Add this to your ~/.bashrc:"
            info "  export PATH=\"$wrapper_dir:\$PATH\""
            echo ""
        fi
    fi
    
    # Install to additional directory if specified
    if [ -n "$INSTALL_DIR" ]; then
        echo ""
        info "Installing additional copies to $INSTALL_DIR..."
        
        local failed=0
        for file in "${INSTALL_FILES[@]}"; do
            local src_path="$REPO_ROOT/$file"
            
            if [ ! -f "$src_path" ]; then
                error "Source file not found: $src_path"
                failed=$((failed + 1))
                continue
            fi
            
            if ! install_file "$src_path" "$INSTALL_DIR"; then
                failed=$((failed + 1))
            fi
        done
        
        if [ $failed -gt 0 ]; then
            error "Some files failed to install to $INSTALL_DIR"
        fi
    fi
    
    echo ""
    info "Installation completed successfully!"
    echo ""
    echo "========================================="
    echo "Installation Summary"
    echo "========================================="
    echo ""
    echo "Printer config directory: $PRINTER_CONFIG_DIR"
    echo "Configuration file: $PRINTER_CONFIG_DIR/.toolchange-config"
    if [ "$install_wrappers" = true ]; then
        echo "Wrapper scripts: $wrapper_dir"
        local printer_name
        printer_name=$(basename "$TARGET_ROOT")
        [ "$printer_name" = "$(basename "$real_home")" ] && printer_name="default"
        echo "  - get_tool_change_status-$printer_name"
        echo "  - tool_change_tracker-$printer_name"
    fi
    echo ""
    echo "========================================="
    echo "Next Steps:"
    echo "========================================="
    echo ""
    echo "1. Configure your printer.cfg using add_to_printer.cfg"
    echo "   from the repository"
    echo ""
    echo "2. Set up OrcaSlicer with M600 command and"
    echo "   PRE_SCAN_TOOL_CHANGES macro"
    echo ""
    echo "3. Test the installation by running a tool change scan:"
    if [ "$install_wrappers" = true ]; then
        echo "   tool_change_tracker-$printer_name scan /path/to/file.gcode"
    else
        echo "   $PRINTER_CONFIG_DIR/tool_change_tracker.py scan /path/to/file.gcode"
    fi
    echo ""
    echo "For more information, see README.md"
    echo ""
}

# Run main function
main "$@"
