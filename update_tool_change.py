#!/usr/bin/env python3
import os
import json
import sys
import pwd

def get_real_user():
    """Get the real user when running under sudo."""
    sudo_user = os.environ.get('SUDO_USER')
    if sudo_user:
        return sudo_user
    return os.environ.get('USER', os.getlogin())

def get_real_home():
    """Get the home directory of the real user."""
    real_user = get_real_user()
    try:
        return pwd.getpwnam(real_user).pw_dir
    except KeyError:
        return os.path.expanduser("~")

def resolve_printer_config_dir():
    """
    Resolve PRINTER_CONFIG_DIR with fallback logic.
    
    Priority:
    1. PRINTER_CONFIG_DIR environment variable
    2. Read from .toolchange-config file
    3. Auto-scan for printer directories
    
    Returns the resolved config directory or None.
    """
    # Priority 1: Environment variable
    config_dir = os.environ.get('PRINTER_CONFIG_DIR')
    if config_dir and os.path.isdir(config_dir):
        return config_dir
    
    # Priority 2: Check for .toolchange-config in common locations
    search_dirs = [
        config_dir if config_dir else None,
        '.',
        os.path.join(get_real_home(), 'printer_data', 'config'),
        os.path.join(get_real_home(), '.config', 'toolchange'),
    ]
    
    for search_dir in search_dirs:
        if not search_dir:
            continue
        config_file = os.path.join(search_dir, '.toolchange-config')
        if os.path.isfile(config_file):
            try:
                with open(config_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith('PRINTER_CONFIG_DIR='):
                            value = line.split('=', 1)[1].strip('"\'')
                            if os.path.isdir(value):
                                return value
            except Exception:
                pass
    
    # Priority 3: Auto-scan home directory
    real_home = get_real_home()
    candidates = []
    
    # Check if home itself has printer_data/config
    home_config = os.path.join(real_home, 'printer_data', 'config')
    if os.path.isdir(home_config):
        candidates.append(home_config)
    
    # Find directories starting with "printer"
    try:
        for entry in os.scandir(real_home):
            if entry.is_dir() and entry.name.startswith('printer'):
                config_path = os.path.join(entry.path, 'printer_data', 'config')
                if os.path.isdir(config_path):
                    candidates.append(config_path)
    except PermissionError:
        pass
    
    # Return first candidate
    if candidates:
        return candidates[0]
    
    return None

# Determine data file location
PRINTER_CONFIG_DIR = resolve_printer_config_dir()
if PRINTER_CONFIG_DIR:
    DATA_FILE = os.path.join(PRINTER_CONFIG_DIR, "tool_changes.json")
else:
    # Fallback to old behavior
    DATA_FILE = "/tmp/tool_change_data.json"

def update_tool_change():
    # Check if the JSON file exists
    if not os.path.exists(DATA_FILE):
        print("ERROR: Tool change data not found. Please run the pre-scan first.")
        sys.exit(1)

    # Load the JSON data
    with open(DATA_FILE, "r") as f:
        data = json.load(f)

    total_changes = data.get("total_changes", 0)
    current_change = data.get("current_change", 0)

    # If all tool changes have been processed, just output a message and exit
    if current_change >= total_changes:
        print("Tool changes completed.")
        sys.exit(0)

    # Increment the current tool change counter
    current_change += 1
    data["current_change"] = current_change

    # Get the tool change info for the current change (indexing is 0-based)
    change_info = data["changes"][current_change - 1]
    tool_number = change_info.get("tool_number", "Unknown")
    color = change_info.get("color", "Unknown")
    line = change_info.get("line", "Unknown")

    # Save the updated JSON data back to the file
    with open(DATA_FILE, "w") as f:
        json.dump(data, f)
    
    # Set ownership if running as sudo
    sudo_user = os.environ.get('SUDO_USER')
    if sudo_user:
        try:
            pw_record = pwd.getpwnam(sudo_user)
            os.chown(DATA_FILE, pw_record.pw_uid, pw_record.pw_gid)
        except Exception:
            pass

    # Print the latest tool change message
    print(f"Tool Change {current_change} of {total_changes} - {color} (T{tool_number}) at line {line}")

if __name__ == "__main__":
    update_tool_change()
