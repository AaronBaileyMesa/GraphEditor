#!/bin/bash

output="all_swift.txt"
> "$output"  # Clear the output file

# Collect all .swift files recursively, sorted
declare -a files
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find . -type f -name '*.swift' -print0 | sort -z)

# Create Table of Contents
echo "Table of Contents:" >> "$output"
i=1
for file in "${files[@]}"; do
    rel_path="${file#./}"
    echo "$i. $rel_path" >> "$output"
    ((i++))
done
echo "" >> "$output"

# Concatenate each file with notes
for file in "${files[@]}"; do
    name=$(basename "$file")
    path="$(pwd)/${file#./}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mtime=$(stat -f %m "$file")
        modified=$(date -j -r "$mtime" +"%Y-%m-%d %H:%M:%S")
    else
        modified=$(date -r "$file" +"%Y-%m-%d %H:%M:%S")
    fi
    
    echo "--------------------------------------------------" >> "$output"
    echo "File: $name" >> "$output"
    echo "Path: $path" >> "$output"
    echo "Last modified: $modified" >> "$output"
    echo "" >> "$output"
    echo "Contents:" >> "$output"
    cat "$file" >> "$output"
    echo "" >> "$output"
    echo "--------------------------------------------------" >> "$output"
done