#!/usr/bin/env python3
import os
import json
import sys

# Path to the JSON data file (produced by your pre-scan script)
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

    # Print the latest tool change message
    print(f"Tool Change {current_change} of {total_changes} - {color} (T{tool_number}) at line {line}")

if __name__ == "__main__":
    update_tool_change()
