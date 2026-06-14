#!/usr/bin/env bash

output="all_files.txt"
script="$(basename "$0")"
> "$output"

find -L . -type f \
  -not -path './.git*' \
  -not -name "$output" \
  -not -name "$script" \
  -print0 |
while IFS= read -r -d '' file; do
  abs="$(realpath "$file")"

  {
    echo "# $abs"
    while IFS= read -r line; do
      printf '  %s\n' "$line"
    done < "$file"
    echo
    echo
  } >> "$output"
done
