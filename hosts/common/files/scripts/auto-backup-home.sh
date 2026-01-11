#!/usr/bin/env bash

# Don't exit globally on error – we'll handle errors manually
set -u  # undefined vars are still errors

# Configuration
HOSTNAME=$(/run/current-system/sw/bin/hostname)
SOURCE_DIR="/home/temhr/"
BACKUP_DESTINATIONS=(
    "/mirror"
    "/mnt/mirk3"
    "/mnt/mirk1"
)

# NFS mount points (destinations that require mount verification)
NFS_MOUNTS=(
    "/mnt/mirk3"
    "/mnt/mirk1"
)

# Rsync options
RSYNC_OPTS=(
    "-rva"
    # -r  = recursive (copy directories)
    # -v  = verbose (show what's happening)
    # -a  = archive mode: preserves permissions, timestamps, symlinks, devices, etc.
    "--numeric-ids"
    # Preserve UID/GID numbers exactly (do NOT map usernames/group names between systems)
    # Important for backups and restores across different machines
    "--xattrs"
    # Preserve extended attributes (SELinux labels, capabilities, user.* metadata, etc.)
    "--acls"
    # Preserve POSIX Access Control Lists (fine-grained permissions beyond chmod)
    "--delete"
    # Delete files in destination that no longer exist in source
    # Keeps destination as an exact mirror
    "--delete-delay"
    # Perform deletions *after* transfer finishes
    # Safer than immediate deletion (avoids half-synced states)
    "--partial"
    # Keep partially transferred files if interrupted
    # Allows resume instead of restarting large file transfers
    "--inplace"
    # Write directly to destination file instead of temp file
    # Saves disk space
    # WARNING: breaks atomicity & snapshots (bad for ZFS/Btrfs backups)
    "--copy-unsafe-links"
    # Follow symlinks that point *outside* the source tree
    # Copies the *target file* instead of the symlink
    # Useful to avoid broken backups
    # WARNING: can pull in unexpected files


    # =========================
    # INCLUDE ONLY THESE
    # =========================

    # These are symlinks pointing INTO shelf, copy them as symlinks
    "--include=.config"              # symlink itself
    "--include=.local"               # symlink itself
    "--include=Desktop"              # symlink itself
    "--include=Documents"            # symlink itself
    "--include=Downloads"            # symlink itself
    "--include=Music"                # symlink itself
    "--include=Pictures"             # symlink itself
    "--include=Public"               # symlink itself
    "--include=Templates"            # symlink itself
    "--include=Videos"               # symlink itself
    "--include=repast4py-workspace"  # symlink itself

    # Actual files/directories
    "--include=.ssh/***"               # SSH keys
    "--include=.pki/***"               # Certificates
    "--include=Calibre Library/***"    # Ebooks
    "--include=.bash_history"          # Shell history
    "--include=.python_history"        # Python history
    #"--include=.bash/***"              # Bash config
    "--include=.keychain/***"          # Keychain
    "--include=bin/***"                # Personal scripts
    #"--include=.mozilla/***"           # Firefox (optional)

    # EXCLUDE EVERYTHING ELSE (including shelf symlink)
    "--exclude=*"
)

# Rsync options for shelf directory (follow the symlink)
RSYNC_SHELF_OPTS=(
    "-rvaL"  # Follow symlinks for shelf
    "--numeric-ids"
    "--xattrs"
    "--acls"
    "--delete"
    "--delete-delay"
    "--partial"
    "--inplace"

    # EXCLUDE TROUBLESOME SHELF ITEMS (by name)
    "--exclude=*/.config/*"
    "--exclude=*/.local/state/*"
    "--exclude=*/share/Steam/*"
    "--exclude=*/repast4py-workspace/*"
    "--exclude=*/Trash/*"
)

# Function to check if a mount point is properly mounted
is_mount_active() {
    local mount_point="$1"

    echo "  Checking mount: $mount_point"

    # Method 1: Check /proc/mounts for NFS or autofs (systemd automount)
    # With systemd automount, the mount may show as 'autofs' until accessed,
    # then become 'nfs' once triggered
    if grep -q " ${mount_point} nfs" /proc/mounts 2>/dev/null; then
        echo "  ✓ Found NFS mount in /proc/mounts"
    elif grep -q " ${mount_point} autofs" /proc/mounts 2>/dev/null; then
        echo "  ✓ Found autofs mount in /proc/mounts (systemd automount)"
    elif grep -q " ${mount_point} " /proc/mounts 2>/dev/null; then
        local mount_type=$(grep " ${mount_point} " /proc/mounts | awk '{print $3}' | head -1)
        echo "  ✓ Found mount in /proc/mounts (type: $mount_type)"
    else
        echo "  ✗ Not found in /proc/mounts"
        return 1
    fi

    # Method 2: Check accessibility with timeout
    # This will trigger the automount if it's an autofs mount
    if timeout 5 ls "$mount_point" >/dev/null 2>&1; then
        echo "  ✓ Directory is accessible"
    else
        echo "  ✗ Directory not accessible (timeout or error)"
        return 1
    fi

    # Method 3: After accessing, verify it's actually NFS (or at least accessible)
    # Check again after the ls command which may have triggered automount
    if grep -q " ${mount_point} nfs" /proc/mounts 2>/dev/null; then
        echo "  ✓ Confirmed NFS mount active"
    elif grep -q " ${mount_point} autofs" /proc/mounts 2>/dev/null; then
        echo "  ✓ Autofs mount present (systemd automount configured)"
    fi

    # Method 4: Try to get filesystem stats
    if timeout 5 stat "$mount_point" >/dev/null 2>&1; then
        echo "  ✓ Can stat directory"
        local fs_type=$(stat -f -c %T "$mount_point" 2>/dev/null || echo "unknown")
        echo "  Filesystem type: $fs_type"
    else
        echo "  ✗ Cannot stat directory"
        return 1
    fi

    # Method 5: For more robust check, see if we can detect different device
    local parent_dev=$(stat -c %d "$(dirname "$mount_point")" 2>/dev/null)
    local mount_dev=$(stat -c %d "$mount_point" 2>/dev/null)

    if [ -n "$parent_dev" ] && [ -n "$mount_dev" ] && [ "$parent_dev" != "$mount_dev" ]; then
        echo "  ✓ Mount point has different device number than parent (confirmed mounted)"
    fi

    echo "  ✓ Mount verification passed for: $mount_point"
    return 0
}

# Function to check if destination requires mount verification
requires_mount_check() {
    local dest="$1"
    for nfs_mount in "${NFS_MOUNTS[@]}"; do
        if [[ "$dest" == "$nfs_mount" ]]; then
            return 0
        fi
    done
    return 1
}

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
            fi
        else
            echo "Keeping external symlink: $link -> $original_target"
        fi
    done
}

# Function to perform backup, return success/failure
perform_backup() {
    local dest_base="$1"
    local dest_dir="${dest_base}/home/${HOSTNAME}/"

    echo "Backing up to: $dest_dir"

    # Ensure destination directory exists
    if [ ! -d "$dest_dir" ]; then
        echo "Creating destination directory: $dest_dir"
        if ! mkdir -p "$dest_dir"; then
            echo "Error: failed to create $dest_dir"
            return 1
        fi
    fi

    # Perform rsync for home directory (excludes shelf)
    if [ -d "$dest_dir" ]; then
        echo "Running rsync for home directory (excluding shelf)..."
        timeout 3600 /run/current-system/sw/bin/rsync \
            "${RSYNC_OPTS[@]}" \
            "$SOURCE_DIR" \
            "$dest_dir"
        rsync_status=$?
    else
        echo "Error: destination directory not available after mkdir"
        return 1
    fi

    # Interpret rsync status
    case $rsync_status in
        0)
            echo "Home directory rsync completed successfully"
            ;;
        23)
            echo "Home directory rsync completed with warning (code 23: partial transfer), treating as success"
            ;;
        124)
            echo "Error: rsync timed out after 1 hour"
            return 1
            ;;
        *)
            echo "Error: rsync failed with code $rsync_status"
            return 1
            ;;
    esac

    # Backup shelf directory separately (following the symlink)
    if [ -L "$SOURCE_DIR/shelf" ]; then
        echo "Backing up shelf directory..."
        local shelf_real_path=$(readlink -f "$SOURCE_DIR/shelf")

        if [ -d "$shelf_real_path" ]; then
            timeout 3600 /run/current-system/sw/bin/rsync \
                "${RSYNC_SHELF_OPTS[@]}" \
                "$shelf_real_path/" \
                "$dest_dir/shelf/"
            shelf_status=$?

            case $shelf_status in
                0)
                    echo "Shelf directory rsync completed successfully"
                    ;;
                23)
                    echo "Shelf directory rsync completed with warning (code 23), treating as success"
                    ;;
                124)
                    echo "Error: shelf rsync timed out after 1 hour"
                    return 1
                    ;;
                *)
                    echo "Error: shelf rsync failed with code $shelf_status"
                    return 1
                    ;;
            esac
        else
            echo "Warning: shelf symlink target not found: $shelf_real_path"
        fi
    fi

    echo "Converting symlinks..."
    if ! convert_symlinks "$dest_dir" "$SOURCE_DIR"; then
        echo "Warning: symlink conversion failed (non-fatal)"
    fi

    echo "Backup completed to: $dest_dir"
    return 0
}

# Main execution
main() {
    echo "Starting backup for hostname: $HOSTNAME"
    echo "============================================"

    local success=1

    for dest in "${BACKUP_DESTINATIONS[@]}"; do
        echo ""
        echo "Checking destination: $dest"
        echo "--------------------------------------------"

        # Check if destination exists
        if [ ! -d "$dest" ]; then
            echo "  ✗ Destination directory does not exist: $dest"
            continue
        fi
        echo "  ✓ Destination directory exists"

        # Check if this destination requires mount verification
        if requires_mount_check "$dest"; then
            echo "  This is an NFS mount, verifying mount status..."
            if ! is_mount_active "$dest"; then
                echo "  ✗ Skipping $dest - mount verification failed"
                continue
            fi
        else
            echo "  Local destination (no mount check required)"
        fi

        echo ""
        # Attempt backup
        if perform_backup "$dest"; then
            echo "============================================"
            echo "✓ Backup process completed successfully at $dest"
            echo "============================================"
            success=0
            break
        else
            echo "✗ Backup failed for $dest, trying next destination..."
        fi
    done

    if [ $success -ne 0 ]; then
        echo ""
        echo "============================================"
        echo "✗ ERROR: All backup destinations failed"
        echo "============================================"
        echo "Checked destinations:"
        for dest in "${BACKUP_DESTINATIONS[@]}"; do
            echo "  - $dest"
        done
        exit 1
    fi
}

main "$@"
