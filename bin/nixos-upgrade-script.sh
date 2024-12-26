#!/usr/bin/env bash
# This script serves as a wrapper for nixos-rebuild, providing additional functionality
# for managing NixOS configurations with flakes

###################
# Default Values #
###################

# The nixos-rebuild operation to perform (switch, boot, test, etc.)
operation="switch"

# Get the current hostname from the system
hostname=$(/run/current-system/sw/bin/hostname)

# Path to the flake directory, defaults to FLAKE_DIR environment variable
flakeDir="${FLAKE_DIR}"

# Flag to control whether to update flake.lock file
update=false

# Get the current user, which will be used for git operations
user=$(/run/current-system/sw/bin/whoami)

# Store any additional arguments that will be passed to nixos-rebuild
remainingArgs=""

###################
# Help Function   #
###################

# Display usage information when --help is used or when there's an error
function usage() {
    echo "nixos-rebuild Operations Script (NOS) updates your system and your flake.lock file by pulling the latest versions."
    echo ""
    echo "Running the script with no parameters performs the following operations:"
    echo "  1. Pull the latest version of the config"
    echo "  2. Update your flake.lock file"
    echo "  3. Commit any changes back to the repository"
    echo "  4. Run 'nixos-rebuild switch'."
    echo ""
    echo "Advanced usage: nixos-upgrade-script.sh [-o|--operation operation] [-f|--flake path-to-flake] [extra nixos-rebuild parameters]"
    echo "Options:"
    echo " -h, --help          Show this help screen."
    echo " -o, --operation     The nixos-rebuild operation to perform."
    echo " -f, --flake <path>  The path to your flake.nix file (and optionally, the hostname to build)."
    echo " -U, --update        Update and commit flake.lock."
    echo " -u, --user          Which user account to run git commands under."
    echo ""
    exit 2
}

#########################
# Argument Processing   #
#########################

# Store positional arguments in an array
POSITIONAL_ARGS=()

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        # Handle --flake or -f flag: Set the flake directory
        --flake|-f)
            flakeDir="$2"
            shift 2
            ;;
        # Handle --update, --upgrade, or -U flag: Enable flake.lock updates
        --update|--upgrade|-U)
            update=true
            shift
            ;;
        # Handle --operation or -o flag: Set the operation type
        --operation|-o)
            operation="$2"
            shift 2
            ;;
        # Handle --user or -u flag: Set the user for git operations
        --user|-u)
            user="$2"
            shift 2
            ;;
        # Handle --help or -h flag: Show usage information
        --help|-h)
            usage
            exit 0
            ;;
        # Store any other arguments as positional arguments
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Store remaining arguments to pass to nixos-rebuild
remainingArgs=${POSITIONAL_ARGS[@]}

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

#########################
# Main Script Logic     #
#########################

# Change to the flake directory
cd $flakeDir

# Pull latest changes from git repository
echo "Pulling the latest version of the repository..."
/run/wrappers/bin/sudo -u $user git pull

# Update flake.lock if requested
if [ $update = true ]; then
    echo "Updating flake.lock..."
    # Update flake.lock and push changes back to repository
    /run/wrappers/bin/sudo -u $user nix flake update --commit-lock-file && /run/wrappers/bin/sudo -u $user git push
else
    echo "Skipping 'nix flake update'..."
fi

# Construct nixos-rebuild command options
options="--flake $flakeDir $remainingArgs --use-remote-sudo --log-format multiline-with-logs"

# Display and execute the nixos-rebuild command
echo "Running this operation: nixos-rebuild $operation $options"
/run/wrappers/bin/sudo -u root /run/current-system/sw/bin/nixos-rebuild $operation $options

# Exit successfully
exit 0
