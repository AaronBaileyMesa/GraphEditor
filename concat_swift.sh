#!/bin/bash

ROOT_DIR="."  # Project root
OUTPUT_FILE="all_swift_files.swift"

find "$ROOT_DIR" -type f -name "*.swift" | while read -r file; do
    rel_path="${file#"$ROOT_DIR"/}"
    echo "// File: $rel_path" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo -e "\n\n" >> "$OUTPUT_FILE"
done

echo "Concatenated Swift files into: $OUTPUT_FILE"