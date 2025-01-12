#!/usr/bin/env bash

## Exit on error
set -e

## Configuration parameters
operation="switch"                              # The nixos-rebuild operation to use
hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
flakeDir="/home/temhr/nixlab"                   # Path to the flake file (and optionally the hostname)
user="temhr"                                    # Which user account to use for git commands -> $(/run/current-system/sw/bin/whoami)

# 1) Navigates to the Flake directory
# 2) Pulls the latest changes from the Git repository using the specified user

## Git Repository Updates
cd "${flakeDir}" || exit 1

# Constructs the arguments for nixos-rebuild:
    # --flake: Specifies the Flake directory and hostname.
    # --use-remote-sudo: Enables remote sudo for operations.
    # --log-format multiline-with-logs: Improves logging readability

## System Rebuild Options
options="--flake ${flakeDir}#${hostname} --use-remote-sudo"

# If a remote host is specified and the operation isn't build or a dry run:
    # Performs a preliminary remote build

## Remote Build Handling
if [[ -n "${buildHost}" && "$operation" != "build" && "$operation" != *"dry"* ]]; then
  echo "Remote build detected, running this operation first: nixos-rebuild build ${options} --build-host $buildHost"
  /run/current-system/sw/bin/nixos-rebuild build $options --build-host $buildHost
  echo "Remote build complete!"
fi

# Runs the nixos-rebuild command with the specified operation and options

## System Rebuild Execution
echo "Running this operation: nixos-rebuild ${operation} ${options}"
/run/current-system/sw/bin/nixos-rebuild $operation $options

# For boot or switch operations: Lists the new system generations created

## Post-Rebuild Actions
case "$operation" in
  boot|switch)
    echo ""
    echo "New generation created: "
    /run/current-system/sw/bin/nixos-rebuild list-generations
    ;;
esac

## Exit on Success
exit 0
