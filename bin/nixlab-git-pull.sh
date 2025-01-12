#!/usr/bin/env bash

## Exit on error
set -e

# 1) Navigates to the Flake directory
# 2) Pulls the latest changes from the Git repository using the specified user

## Git Repository Updates
cd "/home/temhr/nixlab" || exit 1

echo "Pulling the latest version of the repository..."
/run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/git pull

## Exit on Success
exit 0
