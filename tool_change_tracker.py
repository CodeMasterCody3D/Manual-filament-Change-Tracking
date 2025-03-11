#!/usr/bin/env python3
import os
import re
import json
import sys
import argparse
from math import sqrt

# Configuration
HOME = os.path.expanduser("~")
GCODE_DIR = os.path.join(HOME, "printer_data/gcodes")
DATA_FILE = "/tmp/tool_change_data.json"

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
            print("ERROR: No G-code files found.")
            sys.exit(1)
        latest_file = max(files, key=lambda f: os.path.getmtime(os.path.join(GCODE_DIR, f)))
        return os.path.join(GCODE_DIR, latest_file)
    except Exception as e:
        print(f"ERROR: Could not find G-code file: {e}")
        sys.exit(1)

# Function to find the closest CSS color
def closest_css_color(hex_color):
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
        print(f"WARNING: Color conversion error: {e}")
        return "Unknown"

# Function to extract filament information from G-code
def extract_filament_info(gcode_file):
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
        print(f"WARNING: Failed to extract filament information: {e}")
    
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

def pre_scan_gcode(gcode_path=None):
    """Scan specified G-code file or find latest"""
    try:
        gcode_file = gcode_path or find_latest_gcode()
        
        # Validate file exists
        if not os.path.exists(gcode_file):
            print(f"ERROR: File not found: {gcode_file}")
            sys.exit(1)
        if not gcode_file.endswith(".gcode"):
            print(f"ERROR: Not a G-code file: {gcode_file}")
            sys.exit(1)
            
        print(f"Scanning G-code file: {gcode_file}")
        
        # Extract filament information from the file
        filament_info = extract_filament_info(gcode_file)
        print(f"Detected filaments:")
        for i, info in enumerate(filament_info):
            print(f"  Tool {i}: {info['color_name']} ({info['brand']} {info['material']})")
        
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
        
        with open(DATA_FILE, "w") as f:
            json.dump(data, f, indent=2)
            
        print(f"PRE_SCAN_COMPLETE: {data['total_changes']} tool changes found.")
        print(f"Data saved to: {DATA_FILE}")
        
    except Exception as e:
        print(f"ERROR: Failed to process file: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Tool Change Tracker - Scan G-code files for manual tool changes",
        prog="tooltracker.py"
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
        pre_scan_gcode(args.file)
    else:
        parser.print_help()
        sys.exit(1)
