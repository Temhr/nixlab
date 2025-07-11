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
    "--exclude=*/state/nix/*"
    "--exclude=*/state/home-manager/*"
)

# Function to convert absolute symlinks to relative ones
convert_symlinks() {
    local target_dir="$1"
    local source_dir="$2"

    echo "Converting symlinks in: $target_dir"

    find "$target_dir" -type l 2>/dev/null | while read -r link; do
        target=$(readlink "$link" 2>/dev/null || continue)

        # Only process absolute symlinks
        if [[ "$target" = /* ]]; then
            # Check if the symlink target points within the original source directory
            if [[ "$target" = "$source_dir"* ]]; then
                # Convert the absolute path to the corresponding path in the backup
                relative_part="${target#$source_dir}"
                new_target="${target_dir}${relative_part}"

                # Check if the target exists in the backup
                if [ -e "$new_target" ]; then
                    # Calculate relative path from the symlink to the new target
                    link_dir=$(dirname "$link")
                    relative_target=$(realpath --relative-to="$link_dir" "$new_target" 2>/dev/null || continue)
                    ln -sfn "$relative_target" "$link" 2>/dev/null || continue
                    echo "Converted: $link -> $relative_target"
                else
                    echo "Warning: Target not found in backup: $new_target (for link: $link)"
                fi
            else
                # For symlinks pointing outside the source directory, keep them as-is
                echo "Keeping external symlink: $link -> $target"
            fi
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
        # Use symlinks tool if available (more robust)
        symlinks -rc "$dest_dir" 2>/dev/null || true
    else
        # Use our custom function
        convert_symlinks "$dest_dir" "$SOURCE_DIR"
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
