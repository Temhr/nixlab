#!/usr/bin/env bash
# The NixOS Operations Script (NOS) is a wrapper script for nixos-rebuild and Flake-based configurations.
# It handles pulling the latest version of your repository using Git, running system updates, and pushing changes back up.

## Exit on error
set -e

## Configuration parameters
operation="switch"                              # The nixos-rebuild operation to use
hostname=$(/run/current-system/sw/bin/hostname) # Dynamically determines the system's hostname
flakeDir="/home/temhr/nixlab"                   # Path to the flake file (and optionally the hostname)
update=false                                    # Whether to update and commmit flake.lock
user="temhr"                                    # Which user account to use for git commands -> $(/run/current-system/sw/bin/whoami)
buildHost=""                                    # Which host to use to generate the build (defaults to the local host)
remainingArgs=""                                # All remaining arguments that haven't yet been processed (will be passed to nixos-rebuild)

function usage() {
  echo "The NixOS Operations Script (NOS) is a nixos-rebuild wrapper for system maintenance."
  echo ""
  echo "Running the script with no parameters performs the following operations:"
  echo "  1. Pull the latest version of your Nix config repository"
  echo "  2. Run 'nixos-rebuild switch'."
  echo ""
  echo "Advanced usage: nixos-operations-script.sh [-h | --hostname hostname-to-build] [-o | --operation operation] [-f | --flake path-to-flake] [extra nixos-rebuild parameters]"
  echo ""
  echo "Options:"
  echo " --help                       Show this help screen."
  echo " -f, --flake [path]           The path to your flake.nix file (defualts to the FLAKE_DIR environment variable)."
  echo " -h, --hostname [hostname]    The name of the host to build (defaults to the current system's hostname)."
  echo " -o, --operation [operation]  The nixos-rebuild operation to perform (defaults to 'switch')."
  echo " -U, --update                 Update and commit the flake.lock file."
  echo " -u, --user [username]        Which user account to run git commands under (defaults to the user running this script)."
  echo ""
  exit 0
}

# Processes command-line arguments to override default values.
# Argument processing logic stolen from https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

## Argument Parsing
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-host)
      buildHost="$2"
      shift
      shift
      ;;
    --flake|-f)
      flakeDir="$2"
      shift
      shift
      ;;
    --hostname|-h)
      hostname="$2"
      shift
      shift
      ;;
    --update|--upgrade|-U)
      update=true
      shift
      ;;
    --operation|-o)
      operation="$2"
      shift
      shift
      ;;
    --user|-u)
      user="$2"
      shift
      shift
      ;;
    --help)
      usage
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift
      ;;
  esac
done
remainingArgs=${POSITIONAL_ARGS[*]}
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Ensures the flakeDir is specified; otherwise, the script exits with an error

## Flake Directory Validation
if [ -z "${flakeDir}" ]; then
  echo "Flake directory not specified. Use '--flake <path>' or set \$FLAKE_DIR."
  exit 1
fi

# 1) Navigates to the Flake directory
# 2) Pulls the latest changes from the Git repository using the specified user

## Git Repository Updates
cd "$flakeDir" || exit 1

echo "Pulling the latest version of the repository..."
/run/wrappers/bin/sudo -u "$user" /run/current-system/sw/bin/git pull

# Constructs the arguments for nixos-rebuild:
    # --flake: Specifies the Flake directory and hostname.
    # --use-remote-sudo: Enables remote sudo for operations.
    # --log-format multiline-with-logs: Improves logging readability

## System Rebuild Options
options="--flake ${flakeDir}#${hostname} ${remainingArgs} --use-remote-sudo"

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
