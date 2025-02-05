#!/usr/bin/env bash

## Exit on error
set -e

hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
mirrorDir="/mirror"
serDir="/mnt/mirser"
baseDir="/mnt/mirbase"

if [ -d "$mirrorDir" ]; then
    /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' /home/temhr/ ${mirrorDir}/home/${hostname}/
elif [ -d "$serDir" ]; then
    /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' /home/temhr/ ${serDir}/home/${hostname}/
else
    /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/rsync -rva --delete --exclude '*cache*' --exclude '*Cache*' --exclude '*Trash*' /home/temhr/ ${baseDir}/home/${hostname}/
fi

## Exit on Success
exit 0
