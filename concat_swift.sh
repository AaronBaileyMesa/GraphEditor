#!/bin/bash

ROOT_DIR="."  # Project root
OUTPUT_FILE="watch_ui_overview.txt"

# Clear the output file if it exists
> "$OUTPUT_FILE"

# Find Swift files in watch-related directories, excluding tests
find "$ROOT_DIR" -type f -name "*.swift" -ipath "*watch*" -not -ipath "*test*" | while read -r file; do
    rel_path="${file#"$ROOT_DIR"/}"
    echo "File: $rel_path" >> "$OUTPUT_FILE"
    echo "Key Declarations:" >> "$OUTPUT_FILE"
    
    # Extract key declarations (struct, class, enum, protocol, extension)
    grep -E "^[[:space:]]*(public|private|internal|fileprivate|open)?[[:space:]]*(final)?[[:space:]]*(struct|class|enum|protocol|extension)[[:space:]]+[A-Za-z0-9_]+" "$file" >> "$OUTPUT_FILE" || echo "No key declarations found." >> "$OUTPUT_FILE"
    
    echo -e "\n\n" >> "$OUTPUT_FILE"
done

echo "Generated overview of watch UI-related Swift files into: $OUTPUT_FILE"
