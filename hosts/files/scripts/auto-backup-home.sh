#!/usr/bin/env bash

## Exit on error
set -e

# Configuration
HOSTNAME=$(/run/current-system/sw/bin/hostname)
SOURCE_DIR="/home/temhr/"
BACKUP_DESTINATIONS=(
    "/mirror"
    "/mnt/mirk1"
    "/mnt/mirk3"
)

# Rsync options
RSYNC_OPTS=(
    "-rva"
    "--delete"
    "--force"
    "--exclude=*cache*"
    "--exclude=*Cache*"
    "--exclude=*Trash*"
    "--exclude=.nix-profile"
    "--exclude=result"
)

# Function to convert absolute symlinks to relative ones
convert_symlinks() {
    local target_dir="$1"
    find "$target_dir" -type l 2>/dev/null | while read -r link; do
        target=$(readlink "$link" 2>/dev/null || continue)
        # Only process absolute symlinks that point within the backup
        if [[ "$target" = /* ]] && [[ "$target" = "$target_dir"* ]]; then
            # Calculate relative path
            link_dir=$(dirname "$link")
            relative_target=$(realpath --relative-to="$link_dir" "$target" 2>/dev/null || continue)
            ln -sfn "$relative_target" "$link" 2>/dev/null || continue
        fi
    done
}

# Function to perform backup
perform_backup() {
    local dest_base="$1"
    local dest_dir="${dest_base}/home/${HOSTNAME}/"

    echo "Backing up to: $dest_dir"

    # Check if shelf is mounted
    if ! mountpoint -q "${SOURCE_DIR}shelf" 2>/dev/null; then
        echo "Warning: ${SOURCE_DIR}shelf is not mounted"
    fi

    # Determine if we can use hard links (destination exists)
    if [ -d "$dest_dir" ]; then
        echo "Using incremental backup with hard links"
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync \
            "${RSYNC_OPTS[@]}" \
            "--link-dest=${dest_dir}" \
            "$SOURCE_DIR" \
            "$dest_dir"
    else
        echo "Performing initial backup"
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync \
            "${RSYNC_OPTS[@]}" \
            "$SOURCE_DIR" \
            "$dest_dir"
    fi

    # Convert symlinks to relative paths
    echo "Converting absolute symlinks to relative ones..."
    if command -v symlinks >/dev/null 2>&1; then
        symlinks -rc "$dest_dir" 2>/dev/null || true
    else
        convert_symlinks "$dest_dir"
    fi

    echo "Backup completed to: $dest_dir"
    return 0
}

# Main execution
main() {
    echo "Starting backup for hostname: $HOSTNAME"

    # Find the first available backup destination
    for dest in "${BACKUP_DESTINATIONS[@]}"; do
        if [ -d "$dest" ]; then
            echo "Found backup destination: $dest"
            perform_backup "$dest"
            echo "Backup process completed successfully"
            exit 0
        fi
    done

    echo "Error: No backup destinations available"
    echo "Checked: ${BACKUP_DESTINATIONS[*]}"
    exit 1
}

# Run main function
main "$@"
