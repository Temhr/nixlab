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

# Function to convert all symlinks to relative paths within backup
convert_symlinks() {
    local backup_dir="$1"
    local source_dir="$2"

    echo "Converting all symlinks to relative paths in: $backup_dir"

    find "$backup_dir" -type l 2>/dev/null | while read -r link; do
        original_target=$(readlink "$link" 2>/dev/null || continue)

        # Get the directory containing the symlink
        link_dir=$(dirname "$link")

        # Resolve the original target to an absolute path
        if [[ "$original_target" = /* ]]; then
            # Already absolute
            resolved_target="$original_target"
        else
            # Make relative target absolute by resolving from the link's directory
            resolved_target=$(realpath -m "$link_dir/$original_target" 2>/dev/null || continue)
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
                echo "Converted: $(basename "$link") -> $relative_target"
            else
                echo "Warning: Backup target not found: $backup_target (for link: $(basename "$link"))"
            fi
        else
            echo "Keeping external symlink: $(basename "$link") -> $original_target"
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
