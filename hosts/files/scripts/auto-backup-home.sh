#!/usr/bin/env bash

## Exit on error
set -e

hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
mirrorDir="/mirror"
serDir="/mnt/mirk1"
baseDir="/mnt/mirk3"

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

## Exit on Success
exit 0
