#!/usr/bin/env bash

# Don’t exit on first error, handle manually
set +e

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
    "--delete-before"
    "--force"
    "--exclude=*cache*"
    "--exclude=*Cache*"
    "--exclude=*/.local*"
    "--exclude=*.mozilla*"
    "--exclude=*.steam*"
    "--exclude=*.zen*"
    "--exclude=*.Trash*"
    "--exclude=*.nix-profile*"
    "--exclude=*.nix-defexpr*"
    "--exclude=*nixlab*"
    "--exclude=result"
)

# Function to convert symlinks to point within the backup directory
convert_symlinks() {
    local backup_dir="$1"
    local source_dir="$2"

    echo "Converting symlinks to point within backup directory: $backup_dir"

    source_dir="${source_dir%/}"
    backup_dir="${backup_dir%/}"

    find "$backup_dir" -type l 2>/dev/null | while read -r link; do
        original_target=$(readlink "$link" 2>/dev/null || continue)
        link_dir=$(dirname "$link")

        if [[ "$original_target" = /* ]]; then
            resolved_target="$original_target"
        else
            link_relative_to_backup="${link#$backup_dir/}"
            original_link_dir="$source_dir/$(dirname "$link_relative_to_backup")"
            resolved_target=$(realpath -m "$original_link_dir/$original_target" 2>/dev/null || continue)
        fi

        if [[ "$resolved_target" = "$source_dir"* ]]; then
            relative_part="${resolved_target#$source_dir}"
            backup_target="${backup_dir}${relative_part}"

            if [ -e "$backup_target" ]; then
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

    if ! mountpoint -q "${SOURCE_DIR}shelf" 2>/dev/null; then
        echo "Warning: ${SOURCE_DIR}shelf is not mounted"
    fi

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

    if [ $? -ne 0 ]; then
        echo "Error: rsync failed for $dest_base"
        return 1
    fi

    echo "Converting symlinks to point within backup directory..."
    convert_symlinks "$dest_dir" "$SOURCE_DIR" || echo "Warning: symlink conversion failed"

    echo "Backup completed to: $dest_dir"
    return 0
}

# Main execution
main() {
    echo "Starting backup for hostname: $HOSTNAME"

    for dest in "${BACKUP_DESTINATIONS[@]}"; do
        if mountpoint -q "$dest"; then
            echo "Found mounted backup destination: $dest"
            if perform_backup "$dest"; then
                echo "Backup process completed successfully"
                exit 0
            else
                echo "Backup failed for $dest, trying next..."
            fi
        else
            echo "Skipping $dest (not a mountpoint)"
        fi
    done

    echo "Error: No successful backup destinations"
    echo "Checked: ${BACKUP_DESTINATIONS[*]}"
    exit 1
}

main "$@"
