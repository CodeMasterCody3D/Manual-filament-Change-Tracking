#!/usr/bin/env python3
import os
import re
import json
import sys
import argparse
# Configuration
HOME = os.path.expanduser("~")
GCODE_DIR = os.path.join(HOME, "printer_data/gcodes"
)
DATA_FILE = "/tmp/tool_change_data.json"
TOOL_COLORS = {0: "yellow", 1: "blue", 2: "silver",
3: "green", 4: "clear"}
def find_latest_gcode():
    """Find the most recently modified G-code file i
n the directory."""
    try:
        files = [f for f in os.listdir(GCODE_DIR) if
 f.endswith(".gcode")]
        if not files:
            print("ERROR: No G-code files found.")
            sys.exit(1)
        latest_file = max(files, key=lambda f: os.pa
th.getmtime(os.path.join(GCODE_DIR, f)))
        return os.path.join(GCODE_DIR, latest_file)
    except Exception as e:
        print(f"ERROR: Could not find G-code file: {
e}")
        sys.exit(1)
def pre_scan_gcode(gcode_path=None):
    """Scan specified G-code file or find latest"""
    gcode_file = gcode_path or find_latest_gcode()
    # Validate file exists
    if not os.path.exists(gcode_file):
        print(f"ERROR: File not found: {gcode_file}"
)
        sys.exit(1)
    if not gcode_file.endswith(".gcode"):
        print(f"ERROR: Not a G-code file: {gcode_fil
e}")
        sys.exit(1)
    print(f"Scanning G-code file: {gcode_file}")
    data = {"total_changes": 0, "current_change": 0,
 "changes": []}
    try:
        with open(gcode_file, "r") as f:
            for line_number, line in enumerate(f, 1)
:
                match = re.search(r'; MANUAL_TOOL_CH
ANGE T(\d+)', line)
                if match:
                    tool_number = int(match.group(1)
)
                    tool_color = TOOL_COLORS.get(too
l_number, "Unknown")
                    data["total_changes"] += 1
                    data["changes"].append({
                        "tool_number": tool_number,
                        "color": tool_color,
                        "line": line_number
                    })
        with open(DATA_FILE, "w") as f:
            json.dump(data, f, indent=2)
        print(f"PRE_SCAN_COMPLETE: {data['total_chan
ges']} tool changes found.")
        print(f"Data saved to: {DATA_FILE}")
    except Exception as e:
        print(f"ERROR: Failed to process file: {e}")
        sys.exit(1)
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Tool Change Tracker - Scan G-co
de files for manual tool changes",
        prog="tooltracker.py"
    )
    subparsers = parser.add_subparsers(dest='command
', help='Available commands')
    # Scan command
    scan_parser = subparsers.add_parser('scan', help
='Scan a G-code file')
    scan_parser.add_argument(
        'file',
        nargs='?',
        default=None,
        help='Optional G-code file path. Uses latest
 file if not specified.'
    )
    args = parser.parse_args()
    if args.command == 'scan':
        pre_scan_gcode(args.file)
    else:
        parser.print_help()
        sys.exit(1)