#!/usr/bin/env bash

## Exit on error
set -e

# 1) Navigates to the Flake directory
# 2) Updates flake.lock
# 3) Pushes the change to Git repository using the specified user

## Git Repository Updates
cd "/home/temhr/nixlab" || exit 1

echo "Updating flake.lock..."
/run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/nix flake update --flake /home/temhr/nixlab --commit-lock-file
#/run/wrappers/bin/sudo -u "temhr" git push

## Exit on Success
exit 0
