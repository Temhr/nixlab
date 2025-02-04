#!/usr/bin/env bash

## Exit on error
set -e

hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
mirrorDir="/mirror"
mntDir="/mnt/mirser"

if [ -d "$mirrorDir" ]; then
    /run/current-system/sw/bin/rsync -rva --delete --exclude '.cache/' /home/temhr/ ${mirrorDir}/home/${hostname}/
else
    /run/current-system/sw/bin/rsync -rva --delete --exclude '.cache/' /home/temhr/ ${mntDir}/home/${hostname}/
fi

## Exit on Success
exit 0
