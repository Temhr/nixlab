# Auto-detect System Module
# This module automatically selects the appropriate configuration based on the system's UUID.

{ config, lib, pkgs, systems, ... }:

let
  # Function to detect the current system UUID
  detectSystemUUID = ''
    cat /sys/class/dmi/id/product_uuid 2>/dev/null ||
    ${pkgs.dmidecode}/bin/dmidecode -s system-uuid 2>/dev/null ||
    echo "unknown"
  '';

  # Script to detect the current system and include the appropriate config
  detectScript = pkgs.writeScript "detect-system" ''
    #!/bin/sh
    SYSTEM_UUID=$(${detectSystemUUID})
    echo "Detected System UUID: $SYSTEM_UUID"

    # Export for use in the build process
    export SYSTEM_UUID

    # Find the matching configuration
    case "$SYSTEM_UUID" in
      ${lib.concatStringsSep "\n      " (
        lib.mapAttrsToList (uuid: { configFile, description ? "" }: ''
          ${uuid})
            echo "Using configuration for: ${description} (${configFile})"
            exec nixos-rebuild switch --flake .#${uuid} "$@"
            ;;''
        ) systems
      )}
      *)
        echo "Warning: Unknown system UUID: $SYSTEM_UUID" >&2
        echo "Using default configuration."
        exec nixos-rebuild switch --flake .#default "$@"
        ;;
    esac
  '';

in {
  imports = [
    # Include a default configuration that will be used for unknown systems
    # You need to create this file
    ../../hosts/nixos/default.nix
  ];

  # Create a helper script to auto-detect and apply the right configuration
  environment.systemPackages = [
    (pkgs.writeScriptBin "rebuild-this-system" ''
      #!/bin/sh
      exec ${detectScript} "$@"
    '')
  ];

  # Log which system was detected
  system.activationScripts.logSystemInfo = lib.stringAfter [ "users" ] ''
    SYSTEM_UUID=$(${detectSystemUUID})
    mkdir -p /var/log
    echo "System UUID: $SYSTEM_UUID (detected at $(date))" >> /var/log/system-info.log
  '';
}
