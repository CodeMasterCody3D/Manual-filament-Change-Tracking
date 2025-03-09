#!/bin/bash
# update_tool_colors.sh
# Usage: ./update_tool_colors.sh TOOL_NUMBER NEW_COLOR
# Example: ./update_tool_colors.sh 1 Magenta

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 TOOL_NUMBER NEW_COLOR"
    exit 1
fi

TOOL_NUMBER="$1"
NEW_COLOR="$2"
TRACKER_FILE="/home/cody/tool_change_tracker.py"

# This sed command does the following:
# 1. Matches the entire line starting with "TOOL_COLORS = {" up to the specific tool number's value.
# 2. Replaces the current color (anything between the opening and closing quote) with NEW_COLOR.
sed -i -E "s/(TOOL_COLORS = \{[^}]*\b${TOOL_NUMBER}:\s*\")[^\"]*(\"[^}]*\})/\1${NEW_COLOR}\2/" "$TRACKER_FILE"

echo "Updated tool $TOOL_NUMBER to color $NEW_COLOR in $TRACKER_FILE"
