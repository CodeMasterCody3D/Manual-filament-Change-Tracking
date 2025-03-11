#!/bin/bash
# This script replaces all occurrences of "cody" with the current user's username
# in all files in the current folder and its subdirectories.

# Get the current username
USER_NAME=$(whoami)

echo "Replacing 'cody' with '$USER_NAME' in all files..."

# Recursively find all files and perform an in-place substitution.
# Note: This uses sed's in-place editing (-i) option.
find . -type f -exec sed -i "s/cody/${USER_NAME}/g" {} +

echo "Replacement complete."
