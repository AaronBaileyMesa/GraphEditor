#!/bin/bash

# Concatenates the contents of all .swift files in the current folder and subfolders into a single file.
# This version avoids including the output file itself to prevent issues like infinite loops or unintended inclusion.

OUTPUT_FILE="concatenated.swift"

# Remove the output file if it exists to ensure it's not included in the find results
rm -f "$OUTPUT_FILE"

# Use a temporary file to build the output safely
TEMP_FILE=$(mktemp) || exit 1

# Find and concatenate all .swift files to the temp file
find . -type f -name '*.swift' -exec cat {} + >> "$TEMP_FILE"

# Move the temp file to the output file
mv "$TEMP_FILE" "$OUTPUT_FILE"