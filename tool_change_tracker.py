#!/usr/bin/env python3
import os
import re
import json
import sys
import argparse
import logging
import tempfile
import pwd
import getpass
from math import sqrt

# Configuration
HOME = os.path.expanduser("~")

def get_real_user():
    """Get the real user when running under sudo."""
    # Prefer SUDO_USER
    su = os.environ.get('SUDO_USER')
    if su:
        return su
    for envname in ('USER', 'LOGNAME'):
        v = os.environ.get(envname)
        if v:
            return v
    try:
        return pwd.getpwuid(os.geteuid()).pw_name
    except Exception:
        try:
            return getpass.getuser()
        except Exception:
            return 'root'

def get_real_home():
    """Get the home directory of the real user."""
    user = get_real_user()
    try:
        return pwd.getpwnam(user).pw_dir
    except Exception:
        return os.path.expanduser('~')

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
            except Exception as e:
                logging.debug(f"Error reading {config_file}: {e}")
    
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

# Determine config directory and data file location
PRINTER_CONFIG_DIR = resolve_printer_config_dir()
if PRINTER_CONFIG_DIR:
    DATA_FILE = os.path.join(PRINTER_CONFIG_DIR, os.environ.get('TOOL_CHANGES_JSON', 'tool_changes.json'))
    GCODE_DIR = os.path.join(os.path.dirname(os.path.dirname(PRINTER_CONFIG_DIR)), "gcodes")
else:
    # Fallback to old behavior
    PRINTER_CONFIG_DIR = os.path.join(HOME, "printer_data", "config")
    DATA_FILE = "/tmp/tool_change_data.json"
    GCODE_DIR = os.path.join(HOME, "printer_data/gcodes")

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s: %(message)s'
)

def safe_read_json(filepath):
    """
    Safely read JSON data from a file.
    
    Returns a dictionary with the structure:
    {
        "total_changes": int,
        "current_change": int,
        "changes": [
            {
                "tool_number": int,
                "color": str,
                "brand": str,
                "material": str,
                "full_name": str,
                "line": int
            },
            ...
        ]
    }
    
    Returns default empty structure if file doesn't exist or is invalid.
    """
    default_data = {"total_changes": 0, "current_change": 0, "changes": []}
    
    if not os.path.exists(filepath):
        logging.debug(f"JSON file not found: {filepath}, using default")
        return default_data
    
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        # Validate structure
        if not isinstance(data, dict):
            logging.warning(f"Invalid JSON structure in {filepath}, using default")
            return default_data
        
        # Ensure required keys exist
        if "total_changes" not in data or "current_change" not in data or "changes" not in data:
            logging.warning(f"Missing required keys in {filepath}, using default")
            return default_data
        
        # Type validation
        if not isinstance(data["total_changes"], int) or not isinstance(data["current_change"], int):
            logging.warning(f"Invalid types in {filepath}, using default")
            return default_data
        
        if not isinstance(data["changes"], list):
            logging.warning(f"Invalid changes list in {filepath}, using default")
            return default_data
        
        return data
        
    except json.JSONDecodeError as e:
        logging.error(f"JSON parse error in {filepath}: {e}")
        return default_data
    except Exception as e:
        logging.error(f"Error reading {filepath}: {e}")
        return default_data


def safe_write_json(filepath, data):
    """
    Safely write JSON data to a file using atomic write.
    
    Writes to a temporary file first, then renames to avoid corruption.
    Sets proper ownership when running under sudo.
    """
    try:
        # Validate data structure before writing
        if not isinstance(data, dict):
            raise ValueError("Data must be a dictionary")
        
        required_keys = ["total_changes", "current_change", "changes"]
        for key in required_keys:
            if key not in data:
                raise ValueError(f"Missing required key: {key}")
        
        # Create temp file in the same directory as target
        dir_name = os.path.dirname(filepath)
        if not dir_name:
            dir_name = "."
        
        # Ensure directory exists
        os.makedirs(dir_name, exist_ok=True)
        
        # Write to temporary file
        fd, temp_path = tempfile.mkstemp(dir=dir_name, prefix='.tmp_', suffix='.json')
        try:
            with os.fdopen(fd, 'w') as f:
                json.dump(data, f, indent=2)
            
            # Atomic rename
            os.replace(temp_path, filepath)
            logging.debug(f"Successfully wrote JSON to {filepath}")
            
            # Set ownership if running as sudo
            sudo_user = os.environ.get('SUDO_USER')
            if sudo_user:
                try:
                    import pwd
                    pw_record = pwd.getpwnam(sudo_user)
                    os.chown(filepath, pw_record.pw_uid, pw_record.pw_gid)
                except Exception as e:
                    logging.warning(f"Could not set ownership: {e}")
            
        except Exception:
            # Clean up temp file on error
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            raise
            
    except Exception as e:
        logging.error(f"Error writing JSON to {filepath}: {e}")
        raise


# Embedded CSS Named Colors
CSS_NAMED_COLORS = {
    "#F0F8FF": "AliceBlue", "#FAEBD7": "AntiqueWhite", "#00FFFF": "Aqua", "#7FFFD4": "Aquamarine",
    "#F0FFFF": "Azure", "#F5F5DC": "Beige", "#FFE4C4": "Bisque", "#000000": "Black",
    "#FFEBCD": "BlanchedAlmond", "#0000FF": "Blue", "#8A2BE2": "BlueViolet", "#A52A2A": "Brown",
    "#DEB887": "BurlyWood", "#5F9EA0": "CadetBlue", "#7FFF00": "Chartreuse", "#D2691E": "Chocolate",
    "#FF7F50": "Coral", "#6495ED": "CornflowerBlue", "#FFF8DC": "Cornsilk", "#DC143C": "Crimson",
    "#00008B": "DarkBlue", "#008B8B": "DarkCyan", "#B8860B": "DarkGoldenRod", "#A9A9A9": "DarkGray",
    "#006400": "DarkGreen", "#BDB76B": "DarkKhaki", "#8B008B": "DarkMagenta", "#556B2F": "DarkOliveGreen",
    "#FF8C00": "DarkOrange", "#9932CC": "DarkOrchid", "#8B0000": "DarkRed", "#E9967A": "DarkSalmon",
    "#8FBC8F": "DarkSeaGreen", "#483D8B": "DarkSlateBlue", "#2F4F4F": "DarkSlateGray", "#00CED1": "DarkTurquoise",
    "#9400D3": "DarkViolet", "#FF1493": "DeepPink", "#00BFFF": "DeepSkyBlue", "#696969": "DimGray",
    "#1E90FF": "DodgerBlue", "#B22222": "FireBrick", "#FFFAF0": "FloralWhite", "#228B22": "ForestGreen",
    "#FF00FF": "Fuchsia", "#DCDCDC": "Gainsboro", "#FFD700": "Gold", "#DAA520": "GoldenRod",
    "#808080": "Gray", "#008000": "Green", "#ADFF2F": "GreenYellow", "#F0FFF0": "HoneyDew",
    "#FF69B4": "HotPink", "#CD5C5C": "IndianRed", "#4B0082": "Indigo", "#FFFFF0": "Ivory",
    "#F0E68C": "Khaki", "#E6E6FA": "Lavender", "#FFF0F5": "LavenderBlush", "#7CFC00": "LawnGreen",
    "#FFFACD": "LemonChiffon", "#ADD8E6": "LightBlue", "#F08080": "LightCoral", "#E0FFFF": "LightCyan",
    "#D3D3D3": "LightGray", "#90EE90": "LightGreen", "#FFB6C1": "LightPink", "#FFA07A": "LightSalmon",
    "#20B2AA": "LightSeaGreen", "#87CEFA": "LightSkyBlue", "#B0C4DE": "LightSteelBlue", "#FFFFE0": "LightYellow",
    "#00FF00": "Lime", "#32CD32": "LimeGreen", "#FF00FF": "Magenta", "#800000": "Maroon",
    "#000080": "Navy", "#808000": "Olive", "#FFA500": "Orange", "#FF4500": "OrangeRed",
    "#DA70D6": "Orchid", "#EEE8AA": "PaleGoldenRod", "#98FB98": "PaleGreen", "#AFEEEE": "PaleTurquoise",
    "#DB7093": "PaleVioletRed", "#FFDAB9": "PeachPuff", "#CD853F": "Peru", "#FFC0CB": "Pink",
    "#DDA0DD": "Plum", "#B0E0E6": "PowderBlue", "#800080": "Purple", "#FF0000": "Red",
    "#BC8F8F": "RosyBrown", "#4169E1": "RoyalBlue", "#8B4513": "SaddleBrown", "#FA8072": "Salmon",
    "#F4A460": "SandyBrown", "#2E8B57": "SeaGreen", "#A0522D": "Sienna", "#C0C0C0": "Silver",
    "#87CEEB": "SkyBlue", "#6A5ACD": "SlateBlue", "#708090": "SlateGray", "#FFFAFA": "Snow",
    "#00FF7F": "SpringGreen", "#4682B4": "SteelBlue", "#D2B48C": "Tan", "#008080": "Teal",
    "#D8BFD8": "Thistle", "#FF6347": "Tomato", "#40E0D0": "Turquoise", "#EE82EE": "Violet",
    "#F5DEB3": "Wheat", "#FFFFFF": "White", "#FFFF00": "Yellow", "#9ACD32": "YellowGreen"
}

def find_latest_gcode():
    """Find the most recently modified G-code file in the directory."""
    try:
        files = [f for f in os.listdir(GCODE_DIR) if f.endswith(".gcode")]
        if not files:
            logging.error("No G-code files found in %s", GCODE_DIR)
            return None
        latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(GCODE_DIR, f)))
        return os.path.join(GCODE_DIR, latest_file)
    except Exception as e:
        logging.error("Could not find G-code file: %s", e)
        return None

# Function to find the closest CSS color
def closest_css_color(hex_color):
    """Find the closest CSS named color to the given hex color."""
    try:
        r1, g1, b1 = [int(hex_color[i:i+2], 16) for i in (1, 3, 5)]
        closest_color = None
        min_distance = float('inf')

        for css_hex, name in CSS_NAMED_COLORS.items():
            r2, g2, b2 = [int(css_hex[i:i+2], 16) for i in (1, 3, 5)]
            distance = sqrt((r1 - r2)**2 + (g1 - g2)**2 + (b1 - b2)**2)
            
            if distance < min_distance:
                min_distance = distance
                closest_color = name

        return closest_color or "Unknown"
    except Exception as e:
        logging.warning("Color conversion error: %s", e)
        return "Unknown"

# Function to extract filament information from G-code
def extract_filament_info(gcode_file):
    """
    Extract filament color and type information from G-code file.
    
    Returns a list of dictionaries with filament information for each tool.
    """
    filament_info = []
    colors = []
    types = []
    
    try:
        with open(gcode_file, "r") as f:
            content = f.readlines()
            
        for line in content:
            # Extract colors
            if line.startswith("; filament_colour ="):
                hex_colors = line.strip().split(" = ")[1].split(";")
                for hex_color in hex_colors:
                    if hex_color and hex_color.startswith("#"):
                        colors.append((hex_color, closest_css_color(hex_color)))
            
            # Extract filament types and brands
            if line.startswith("; filament_settings_id ="):
                settings_str = line.strip().split(" = ")[1]
                # Parse the quoted strings
                import re
                filament_types = re.findall(r'"([^"]*)"', settings_str)
                
                for filament_type in filament_types:
                    # Try to extract brand and type
                    parts = filament_type.split(" ")
                    if len(parts) >= 2:
                        brand = parts[0]  # First part is usually the brand
                        material = parts[1]  # Second part is usually the material type
                        types.append({"brand": brand, "material": material, "full_name": filament_type})
                    else:
                        types.append({"brand": "Unknown", "material": "Unknown", "full_name": filament_type})
        
        # Match colors with types
        for i in range(max(len(colors), len(types))):
            color_info = colors[i] if i < len(colors) else ("#FFFFFF", "Unknown")
            type_info = types[i] if i < len(types) else {"brand": "Unknown", "material": "Unknown", "full_name": "Unknown"}
            
            filament_info.append({
                "hex_color": color_info[0],
                "color_name": color_info[1],
                "brand": type_info["brand"],
                "material": type_info["material"],
                "full_name": type_info["full_name"]
            })
            
    except Exception as e:
        logging.warning("Failed to extract filament information: %s", e)
    
    # Fallback to default values if none found
    if not filament_info:
        default_colors = {0: "Yellow", 1: "Blue", 2: "Silver", 3: "Green", 4: "White"}
        for i in range(5):
            filament_info.append({
                "hex_color": f"#{i}",
                "color_name": default_colors.get(i, "Unknown"),
                "brand": "Unknown",
                "material": "Unknown", 
                "full_name": "Unknown"
            })
    
    return filament_info

def pre_scan_gcode(gcode_path=None, dry_run=False, verbose=False):
    """
    Scan specified G-code file or find latest.
    
    Args:
        gcode_path: Path to G-code file, or None to find latest
        dry_run: If True, don't write output file
        verbose: If True, enable verbose logging
    
    Returns:
        0 on success, non-zero on error
    """
    if verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        gcode_file = gcode_path or find_latest_gcode()
        
        if not gcode_file:
            logging.error("No G-code file found")
            return 1
        
        # Validate file exists
        if not os.path.exists(gcode_file):
            logging.error("File not found: %s", gcode_file)
            return 1
        if not gcode_file.endswith(".gcode"):
            logging.error("Not a G-code file: %s", gcode_file)
            return 1
            
        logging.info("Scanning G-code file: %s", gcode_file)
        
        # Extract filament information from the file
        filament_info = extract_filament_info(gcode_file)
        logging.info("Detected filaments:")
        for i, info in enumerate(filament_info):
            logging.info("  Tool %d: %s (%s %s)", i, info['color_name'], info['brand'], info['material'])
        
        data = {"total_changes": 0, "current_change": 0, "changes": []}
        
        with open(gcode_file, "r") as f:
            for line_number, line in enumerate(f, 1):
                match = re.search(r'; MANUAL_TOOL_CHANGE T(\d+)', line)
                if match:
                    tool_number = int(match.group(1))
                    if tool_number < len(filament_info):
                        info = filament_info[tool_number]
                        tool_color = info["color_name"]
                        tool_brand = info["brand"]
                        tool_material = info["material"]
                        tool_full_name = info["full_name"]
                    else:
                        tool_color = "Unknown"
                        tool_brand = "Unknown"
                        tool_material = "Unknown"
                        tool_full_name = "Unknown"
                    
                    data["total_changes"] += 1
                    data["changes"].append({
                        "tool_number": tool_number,
                        "color": tool_color,
                        "brand": tool_brand,
                        "material": tool_material,
                        "full_name": tool_full_name,
                        "line": line_number
                    })
        
        if dry_run:
            logging.info("DRY RUN: Would write to %s", DATA_FILE)
            logging.debug("Data: %s", json.dumps(data, indent=2))
        else:
            safe_write_json(DATA_FILE, data)
            logging.info("Data saved to: %s", DATA_FILE)
            
        logging.info("PRE_SCAN_COMPLETE: %d tool changes found.", data['total_changes'])
        return 0
        
    except Exception as e:
        logging.error("Failed to process file: %s", e)
        return 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Tool Change Tracker - Scan G-code files for manual tool changes",
        prog="tool_change_tracker.py"
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without writing output file'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose logging'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Scan command
    scan_parser = subparsers.add_parser('scan', help='Scan a G-code file')
    scan_parser.add_argument(
        'file',
        nargs='?',
        default=None,
        help='Optional G-code file path. Uses latest file if not specified.'
    )
    
    args = parser.parse_args()
    
    if args.command == 'scan':
        exit_code = pre_scan_gcode(args.file, dry_run=args.dry_run, verbose=args.verbose)
        sys.exit(exit_code)
    else:
        parser.print_help()
        sys.exit(1)
