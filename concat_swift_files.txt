#!/bin/bash

output="all_swift_ui_context.txt"  # Changed name to reflect focus on UI/interactivity
> "$output"  # Clear the output file

# Header note for context
echo "## Focused Project Concatenation" >> "$output"
echo "This file includes only UI, interactivity, model, and core logic files." >> "$output"
echo "Excluded: Tests/*, UITests/*, Package.swift, AppDelegate.swift, and other non-UI items." >> "$output"
echo "Current date: $(date +"%Y-%m-%d %H:%M:%S")" >> "$output"  # Add timestamp for reference
echo "" >> "$output"

# Collect all relevant .swift files recursively, sorted, with exclusions
declare -a files
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find . -type f -name '*.swift' \
    ! -path '*/Tests/*' \
    ! -path '*/UITests/*' \
    ! -name 'Package.swift' \
    ! -name 'AppDelegate.swift' \
    -print0 | sort -z)

if [ ${#files[@]} -eq 0 ]; then
    echo "No relevant .swift files found (after exclusions)." >> "$output"
    exit 0
fi

# Create Table of Contents (using relative paths)
echo "Table of Contents:" >> "$output"
i=1
for file in "${files[@]}"; do
    rel_path="${file#./}"
    echo "$i. $rel_path" >> "$output"
    ((i++))
done
echo "" >> "$output"

# Concatenate each file with concise metadata
for file in "${files[@]}"; do
    name=$(basename "$file")
    rel_path="${file#./}"  # Relative path for simplicity (instead of absolute)
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mtime=$(stat -f %m "$file")
        modified=$(date -j -r "$mtime" +"%Y-%m-%d %H:%M:%S")
    else
        modified=$(date -r "$file" +"%Y-%m-%d %H:%M:%S")
    fi
    
    echo "--------------------------------------------------" >> "$output"
    echo "File: $name" >> "$output"
    echo "Path: $rel_path" >> "$output"
    echo "Last modified: $modified" >> "$output"
    echo "" >> "$output"
    echo "Contents:" >> "$output"
    cat "$file" >> "$output"
    echo "--------------------------------------------------" >> "$output"
done

echo "Script completed. Output written to $output."