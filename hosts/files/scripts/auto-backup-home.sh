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

# Function to convert symlinks to point within the backup directory
convert_symlinks() {
    local backup_dir="$1"
    local source_dir="$2"

    echo "Converting symlinks to point within backup directory: $backup_dir"

    # Remove trailing slash from source_dir for consistent matching
    source_dir="${source_dir%/}"
    backup_dir="${backup_dir%/}"

    find "$backup_dir" -type l 2>/dev/null | while read -r link; do
        original_target=$(readlink "$link" 2>/dev/null || continue)

        # Get the directory containing the symlink
        link_dir=$(dirname "$link")

        # Resolve the original target to an absolute path
        if [[ "$original_target" = /* ]]; then
            # Already absolute
            resolved_target="$original_target"
        else
            # Make relative target absolute by resolving from the original source location
            # We need to map the link's backup location back to source location
            link_relative_to_backup="${link#$backup_dir/}"
            original_link_dir="$source_dir/$(dirname "$link_relative_to_backup")"
            resolved_target=$(realpath -m "$original_link_dir/$original_target" 2>/dev/null || continue)
        fi

        # Check if the resolved target is within the original source directory
        if [[ "$resolved_target" = "$source_dir"* ]]; then
            # Map the source path to the backup path
            relative_part="${resolved_target#$source_dir}"
            backup_target="${backup_dir}${relative_part}"

            # Check if the target exists in the backup
            if [ -e "$backup_target" ]; then
                # Calculate relative path from the symlink to the backup target
                relative_target=$(realpath --relative-to="$link_dir" "$backup_target" 2>/dev/null || continue)
                ln -sfn "$relative_target" "$link" 2>/dev/null || continue
                echo "Converted: $link"
                echo "  From: $original_target"
                echo "  To:   $relative_target"
            else
                echo "Warning: Backup target not found: $backup_target"
                echo "  Original link: $link -> $original_target"
            fi
        else
            echo "Keeping external symlink: $link -> $original_target"
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

    # Convert symlinks to point within backup directory
    echo "Converting symlinks to point within backup directory..."
    convert_symlinks "$dest_dir" "$SOURCE_DIR"

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
