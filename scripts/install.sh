#!/bin/bash
# install.sh - Interactive installer for Manual Filament Change Tracking tools
#
# This script installs the tool change tracking utilities to a chosen directory.

set -e
set -u

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_INSTALL_DIR="/usr/local/bin"
NONINTERACTIVE=false

# Files to install
INSTALL_FILES=(
    "tool_change_tracker.py"
    "update_tool_change.py"
    "scripts/get_tool_change_status.sh"
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
        echo -e "${GREEN}[INFO]${NC} Directory $dir does not exist." >&2
        if confirm "Create it?"; then
            if ! mkdir -p "$dir"; then
                error "Failed to create directory $dir"
                exit 1
            fi
            echo -e "${GREEN}[INFO]${NC} Created directory $dir" >&2
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

# Main installation logic
main() {
    parse_args "$@"
    
    echo "========================================="
    echo "Manual Filament Change Tracking Installer"
    echo "========================================="
    echo ""
    
    # Validate and prepare install directory
    INSTALL_DIR=$(validate_install_dir "$INSTALL_DIR")
    
    info "Install directory: $INSTALL_DIR"
    echo ""
    
    # Show what will be installed
    info "The following files will be installed:"
    for file in "${INSTALL_FILES[@]}"; do
        echo "    - $(basename "$file")"
    done
    echo ""
    
    # Confirm installation
    if ! confirm "Proceed with installation?" "y"; then
        info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    info "Installing files..."
    
    # Install each file
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
    
    echo ""
    
    if [ $failed -eq 0 ]; then
        info "Installation completed successfully!"
        echo ""
        echo "========================================="
        echo "Next Steps:"
        echo "========================================="
        echo ""
        echo "1. Ensure $INSTALL_DIR is in your PATH"
        echo "   Add this to your ~/.bashrc or ~/.profile if needed:"
        echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
        echo ""
        echo "2. Test the installation:"
        echo "   tool_change_tracker.py --help"
        echo "   get_tool_change_status.sh --help"
        echo ""
        echo "3. Configure your printer.cfg using add_to_printer.cfg"
        echo "   from the repository"
        echo ""
        echo "4. Set up OrcaSlicer with M600 command and"
        echo "   PRE_SCAN_TOOL_CHANGES macro"
        echo ""
        echo "For more information, see README.md"
        echo ""
    else
        error "Installation completed with $failed error(s)"
        exit 1
    fi
}

# Run main function
main "$@"
