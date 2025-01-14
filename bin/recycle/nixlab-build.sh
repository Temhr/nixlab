#!/usr/bin/env bash

## Exit on error
set -e

## Configuration parameters
hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
user=$(/run/current-system/sw/bin/whoami)       # Which user account to use for git commands -> $(/run/current-system/sw/bin/whoami)

echo "${user}" > /home/temhr/who.txt

## System Rebuild Execution
echo "Running this operation: nixos-rebuild switch --flake /home/temhr/nixlab#${hostname}" >> /home/temhr/who.txt
/run/current-system/sw/bin/nixos-rebuild switch --flake /home/temhr/nixlab#${hostname} >> /home/temhr/who.txt

echo "" >> /home/temhr/who.txt
echo "New generation created: " >> /home/temhr/who.txt
/run/current-system/sw/bin/nixos-rebuild list-generations >> /home/temhr/who.txt


## Exit on Success
exit 0
