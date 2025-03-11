#!/bin/bash
# Reads the current tool change progress from JSON and prints it.
JSON_FILE="/tmp/tool_change_data.json"
if [ ! -f "$JSON_FILE" ]; then
    echo "ERROR: No tool change data found."
    exit 1
fi
current_change=$(jq '.current_change' "$JSON_FILE")
total_changes=$(jq '.total_changes' "$JSON_FILE")
if [ "$current_change" -ge "$total_changes" ]; then
    echo "Tool changes completed."
    exit 0
fi
# Extract the tool number and color for the current
change
tool_number=$(jq ".changes[$current_change].tool_number" "$JSON_FILE")
color=$(jq -r ".changes[$current_change].color" "$JSON_FILE")
line=$(jq ".changes[$current_change].line" "$JSON_FILE")
echo "Tool Change $((current_change + 1)) of $total_changes - $color (T$tool_number) at line $line"
