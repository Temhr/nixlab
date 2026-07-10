#!/usr/bin/env bash

output="all_files.txt"
path_output="all_filepaths.txt"
script="$(basename "$0")"

> "$output"
> "$path_output"

find -L . -type f \
  -not -path './.git*' \
  -not -name "$output" \
  -not -name "$path_output" \
  -not -name "$script" \
  -print0 |
while IFS= read -r -d '' file; do
  abs="$(realpath "$file")"

  # Write just the path to the second file
  printf '%s\n' "$abs" >> "$path_output"

  # Write the file contents to the main output
  {
    echo "# $abs"
    while IFS= read -r line; do
      printf '  %s\n' "$line"
    done < "$file"
    echo
    echo
  } >> "$output"
done
