#!/bin/bash

# Define the path to the printer.cfg file
PRINTER_CFG="/home/$USER/printer_data/config/printer.cfg"

# Function to create a backup of the printer.cfg file
backup_config() {
    BACKUP_DIR="/home/$USER/printer_data/backups"
    mkdir -p "$BACKUP_DIR"  # Ensure the backup directory exists

    # Create a timestamp for the backup filename
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/printer_cfg_backup_$TIMESTAMP.cfg"

    # Copy the printer.cfg to the backup location
    cp "$PRINTER_CFG" "$BACKUP_FILE"
    echo "Backup of printer.cfg created at: $BACKUP_FILE"
}

# Function to replace a macro in the printer.cfg
replace_macro() {
    MACRO_NAME=$1
    NEW_MACRO_CONTENT=$2

    # Temp file to store the updated configuration
    TEMP_FILE=$(mktemp)

    # Flag to track if we are inside the macro we want to replace
    IN_MACRO=false

    # Read the printer.cfg file line by line
    while IFS= read -r line; do
        # Check if this is the start of the macro
        if [[ "$line" == "[gcode_macro $MACRO_NAME]" ]]; then
            IN_MACRO=true
            echo "$line" >> "$TEMP_FILE"  # Keep the macro header
            # Add the new macro content
            echo "$NEW_MACRO_CONTENT" >> "$TEMP_FILE"
        elif [[ "$line" =~ ^gcode_macro\ .* ]] && [ "$IN_MACRO" = true ]; then
            # If we encounter a new macro header and we were inside the macro,
            # stop adding lines for the current macro
            IN_MACRO=false
            echo "$line" >> "$TEMP_FILE"
        elif [[ "$line" =~ ^gcode_shell_command\ .* ]] && [ "$IN_MACRO" = true ]; then
            # Stop the macro at any shell command if we were inside the macro
            IN_MACRO=false
            echo "$line" >> "$TEMP_FILE"
        elif [ "$IN_MACRO" = false ]; then
            # If we're not inside a macro, just copy the line as is
            echo "$line" >> "$TEMP_FILE"
        fi
    done < "$PRINTER_CFG"

    # Overwrite the original printer.cfg with the updated content
    mv "$TEMP_FILE" "$PRINTER_CFG"
}

# Backup the printer.cfg before making any changes
backup_config

# Example of replacing the PAUSE macro
NEW_PAUSE_MACRO="gcode for your new PAUSE macro here"
replace_macro "PAUSE" "$NEW_PAUSE_MACRO"

# Example of replacing the RESUME macro
NEW_RESUME_MACRO="gcode for your new RESUME macro here"
replace_macro "RESUME" "$NEW_RESUME_MACRO"

# You can replace other macros by calling `replace_macro` with their names and new content
