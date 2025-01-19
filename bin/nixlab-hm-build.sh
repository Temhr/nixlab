#!/usr/bin/env bash

## Exit on error
set -e

# 1) Navigates to the Flake directory
# 2) Updates Home Manager

## Git Repository Updates
cd "/home/temhr/nixlab" || exit 1

echo "Updating Home Manager..."
/run/current-system/sw/bin/home-manager switch --flake /home/temhr/nixlab

## Exit on Success
exit 0
