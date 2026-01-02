find /home/temhr/ -type l -exec bash -c '
    for link; do
        target=$(readlink -f "$link" 2>/dev/null)
        if [[ "$target" == "$link"* ]] || [[ "$link" == "$target"* ]]; then
            echo "Circular symlink: $link -> $(readlink "$link")"
        fi
    done
' bash {} +
