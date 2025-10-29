#!/bin/bash

# Check if directory argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory>"
    echo "Example: $0 /path/to/your/project"
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_ZIP="swift_files_$(date +%Y%m%d_%H%M%S).zip"

# Check if the directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Directory '$SOURCE_DIR' not found."
    exit 1
fi

# Change to the source directory and zip all .swift files
echo "Zipping all .swift files from: $SOURCE_DIR"
echo "Output: $OUTPUT_ZIP"

# Use find + zip to recursively collect and compress .swift files
cd "$SOURCE_DIR" || exit 1
find . -type f -name "*.swift" -print0 | xargs -0 zip -r "../$OUTPUT_ZIP"

# Check if zip was successful
if [ $? -eq 0 ]; then
    echo "Successfully created: $(realpath "../$OUTPUT_ZIP")"
else
    echo "Failed to create zip archive."
    exit 1
fi