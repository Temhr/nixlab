#!/usr/bin/env bash

OUTPUT_FILE="combined_output.txt"
LIST_FILE="files.txt"

if [ ! -f "$LIST_FILE" ]; then
    echo "Error: List file $LIST_FILE not found."
    exit 1
fi

> "$OUTPUT_FILE"

# Read the list file line by line (handles spaces in file paths correctly)
while IFS= read -r FILE || [ -n "$FILE" ]; do
    # Skip empty lines
    [ -z "$FILE" ] && continue

    if [ -f "$FILE" ]; then
        echo "# $FILE" >> "$OUTPUT_FILE"
        cat "$FILE" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    else
        echo "Warning: File not found: $FILE"
    fi
done < "$LIST_FILE"

echo "Done! All contents appended."
