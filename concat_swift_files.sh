#!/bin/bash

output_dir="swift_ui_context_parts"  # Folder for output parts
mkdir -p "$output_dir"  # Create directory if needed

# Header template
common_header() {
    echo "## Focused Project Concatenation"
    echo "This file includes only UI, interactivity, model, and core logic files."
    echo "Excluded: Tests/*, UITests/*, Package.swift, AppDelegate.swift, and other non-UI items."
    echo "Current date: $(date +"%Y-%m-%d %H:%M:%S")"
    echo ""
}

# Max characters per file
max_chars=44613

# Collect all relevant .swift files recursively, sorted, with exclusions
declare -a files
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find . -type f -name '*.swift' \
    ! -path '*/Tests/*' \
    ! -path '*/UITests/*' \
    ! -name 'Package.swift' \
    ! -name 'AppDelegate.swift' \
    -print0 | tr '\0' '\n' | sort | tr '\n' '\0')

# Filter out empty or invalid files
declare -a new_files
for f in "${files[@]}"; do
    if [ -n "$f" ] && [ -f "$f" ]; then
        new_files+=("$f")
    fi
done
files=("${new_files[@]}")

if [ ${#files[@]} -eq 0 ]; then
    echo "No relevant .swift files found (after exclusions)."
    exit 0
fi

# Function to build TOC string for given files array
build_toc() {
    local -a part_files=("$@")
    local toc="Table of Contents:\n"
    local i=1
    for file in "${part_files[@]}"; do
        rel_path="${file#./}"
        toc+="$i. $rel_path\n"
        ((i++))
    done
    toc+="\n"
    echo -e "$toc"
}

# Function to build block for a single file
build_block() {
    local file="$1"
    if [ -z "$file" ]; then
        return
    fi
    local name=$(basename "$file")
    local rel_path="${file#./}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        mtime=$(stat -f %m "$file")
        modified=$(date -j -r "$mtime" +"%Y-%m-%d %H:%M:%S")
    else
        modified=$(date -r "$file" +"%Y-%m-%d %H:%M:%S")
    fi
    echo -e "--------------------------------------------------\nFile: $name\nPath: $rel_path\nLast modified: $modified\n\nContents:\n$(cat "$file")\n--------------------------------------------------\n"
}

# Process files into parts
declare -a current_files
part_num=1
for file in "${files[@]}"; do
    current_files+=("$file")
    
    # Build hypothetical full content
    header=$(common_header)
    toc=$(build_toc "${current_files[@]}")
    blocks=""
    for f in "${current_files[@]}"; do
        blocks+=$(build_block "$f")
    done
    full="${header}\n${toc}${blocks}"
    length=${#full}
    
    if [ $length -gt $max_chars ]; then
        if [ ${#current_files[@]} -gt 0 ]; then
            # Remove last file
            last_index=$((${#current_files[@]} - 1))
            last_file=${current_files[$last_index]}
            unset 'current_files[$last_index]'
            
            # Build without last, only if still not empty
            if [ ${#current_files[@]} -gt 0 ]; then
                header=$(common_header)
                toc=$(build_toc "${current_files[@]}")
                blocks=""
                for f in "${current_files[@]}"; do
                    blocks+=$(build_block "$f")
                done
                full="${header}\n${toc}${blocks}"
                
                # Write to part file
                output_file="$output_dir/part-${part_num}.txt"
                echo -e "$full" > "$output_file"
                ((part_num++))
            fi
            
            # Start new part with last file
            current_files=("$last_file")
        fi
    fi
done

# Write the last part if any
if [ ${#current_files[@]} -gt 0 ]; then
    header=$(common_header)
    toc=$(build_toc "${current_files[@]}")
    blocks=""
    for f in "${current_files[@]}"; do
        blocks+=$(build_block "$f")
    done
    full="${header}\n${toc}${blocks}"
    output_file="$output_dir/part-${part_num}.txt"
    echo -e "$full" > "$output_file"
fi

echo "Script completed. Outputs written to $output_dir/part-*.txt"