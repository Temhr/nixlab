#!/usr/bin/env bash
# The NixOS Operations Script (NOS) is a wrapper script for nixos-rebuild and Flake-based configurations.
# It handles pulling the latest version of your repository using Git, running system updates, and pushing changes back up.

# Exit script immediately if any command exits with a non-zero status
set -e

###################
# Default Values  #
###################

# The nixos-rebuild operation to perform (switch, boot, test, etc.)
operation="switch"

# Get the current system's hostname
hostname=$(/run/current-system/sw/bin/hostname)

# Path to the flake directory, defaults to FLAKE_DIR environment variable
flakeDir="${FLAKE_DIR}"

# Flag to control whether to update and commit flake.lock file
update=false

# Get the current user for git operations
user=$(/run/current-system/sw/bin/whoami)

# Optional remote build host specification
buildHost=""

# Store any additional arguments to pass to nixos-rebuild
remainingArgs=""

###################
# Help Function   #
###################

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

#########################
# Argument Processing   #
#########################

# Store positional arguments in an array
POSITIONAL_ARGS=()

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        # Handle --build-host flag: Set remote build host
        --build-host)
            buildHost="$2"
            shift 2
            ;;
        # Handle --flake or -f flag: Set flake directory
        --flake|-f)
            flakeDir="$2"
            shift 2
            ;;
        # Handle --hostname or -h flag: Set target hostname
        --hostname|-h)
            hostname="$2"
            shift 2
            ;;
        # Handle --update flags: Enable flake.lock updates
        --update|--upgrade|-U)
            update=true
            shift
            ;;
        # Handle --operation or -o flag: Set operation type
        --operation|-o)
            operation="$2"
            shift 2
            ;;
        # Handle --user or -u flag: Set git operations user
        --user|-u)
            user="$2"
            shift 2
            ;;
        # Handle --help flag: Show usage information
        --help)
            usage
            ;;
        # Store any other arguments as positional arguments
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Store remaining arguments to pass to nixos-rebuild
remainingArgs=${POSITIONAL_ARGS[*]}

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

#########################
# Input Validation      #
#########################

# Check if flake directory is specified
if [ -z "${flakeDir}" ]; then
    echo "Flake directory not specified. Use '--flake <path>' or set \$FLAKE_DIR."
    exit 1
fi

# Change to the flake directory or exit if it fails
cd "$flakeDir" || exit 1

#########################
# Repository Updates    #
#########################

# Pull latest changes from git repository
echo "Pulling the latest version of the repository..."
/run/wrappers/bin/sudo -u "$user" /run/current-system/sw/bin/git pull

# Update flake.lock if requested
if [ $update = true ]; then
    echo "Updating flake.lock..."
    # Update flake.lock and push changes back to repository
    /run/wrappers/bin/sudo -u "$user" /run/current-system/sw/bin/nix flake update --commit-lock-file
    /run/wrappers/bin/sudo -u "$user" git push
else
    echo "Skipping 'nix flake update'..."
fi

#########################
# System Rebuild        #
#########################

# Construct nixos-rebuild command options
options="--flake ${flakeDir}#${hostname} ${remainingArgs} --use-remote-sudo --log-format multiline-with-logs"

# Handle remote builds if specified and appropriate
if [[ -n "${buildHost}" && "$operation" != "build" && "$operation" != *"dry"* ]]; then
    echo "Remote build detected, running this operation first: nixos-rebuild build ${options} --build-host $buildHost"
    /run/current-system/sw/bin/nixos-rebuild build $options --build-host $buildHost
    echo "Remote build complete!"
fi

# Execute the main nixos-rebuild command
echo "Running this operation: nixos-rebuild ${operation} ${options}"
/run/current-system/sw/bin/nixos-rebuild $operation $options

#########################
# Post-Build Actions    #
#########################

# Show generation information for boot/switch operations
case "$operation" in
    boot|switch)
        echo ""
        echo "New generation created: "
        /run/current-system/sw/bin/nixos-rebuild list-generations
        ;;
esac

# Exit successfully
exit 0
