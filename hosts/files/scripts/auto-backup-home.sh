#!/usr/bin/env bash

## Exit on error
set -e

# Function to convert absolute symlinks to relative ones
convert_symlinks() {
    local target_dir="$1"
    find "$target_dir" -type l | while read -r link; do
        target=$(readlink "$link")
        # Only process absolute symlinks that point within the backup
        if [[ "$target" = /* ]] && [[ "$target" = "$target_dir"* ]]; then
            # Calculate relative path
            link_dir=$(dirname "$link")
            relative_target=$(realpath --relative-to="$link_dir" "$target")
            ln -sfn "$relative_target" "$link"
        fi
    done
}

hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
mirrorDir="/mirror"
serDir="/mnt/mirk1"
baseDir="/mnt/mirk3"

# Check if shelf is mounted
if ! mountpoint -q /home/temhr/shelf; then
    echo "Warning: /home/temhr/shelf is not mounted"
fi

if [ -d "$mirrorDir" ]; then
    if [ -d "${mirrorDir}/home/${hostname}/" ]; then
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' --link-dest=${mirrorDir}/home/${hostname}/ /home/temhr/ ${mirrorDir}/home/${hostname}/
    else
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' /home/temhr/ ${mirrorDir}/home/${hostname}/
    fi
elif [ -d "$serDir" ]; then
    if [ -d "${serDir}/home/${hostname}/" ]; then
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' --link-dest=${serDir}/home/${hostname}/ /home/temhr/ ${serDir}/home/${hostname}/
    else
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' /home/temhr/ ${serDir}/home/${hostname}/
    fi
else
    if [ -d "${baseDir}/home/${hostname}/" ]; then
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' --link-dest=${baseDir}/home/${hostname}/ /home/temhr/ ${baseDir}/home/${hostname}/
    else
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' /home/temhr/ ${baseDir}/home/${hostname}/
    fi
fi

# Convert absolute symlinks to relative ones within the backup
# This makes the backup portable - symlinks will work even if the backup is moved
if [ -d "$mirrorDir" ]; then
    backupPath="${mirrorDir}/home/${hostname}/"
elif [ -d "$serDir" ]; then
    backupPath="${serDir}/home/${hostname}/"
else
    backupPath="${baseDir}/home/${hostname}/"
fi

# Convert absolute symlinks to relative ones
if command -v symlinks >/dev/null 2>&1; then
    symlinks -rc "$backupPath" 2>/dev/null || true
else
    echo "Converting absolute symlinks to relative ones..."
    convert_symlinks "$backupPath"
fi

## Exit on Success
exit 0
