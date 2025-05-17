# UUID Detection Module for NixOS
# This module adds UUID detection capabilities to your NixOS configuration.

{ config, lib, pkgs, ... }:

{
  # Add system UUID detection capability
  config = {
    # Log the system UUID at boot time for easy reference
    boot.postBootCommands = lib.mkAfter ''
      SYSTEM_UUID=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null ||
                  ${pkgs.dmidecode}/bin/dmidecode -s system-uuid 2>/dev/null ||
                  echo "unknown")
      echo "System UUID: $SYSTEM_UUID" >> /var/log/system-info.log
    '';

    # Make UUID available as a system property
    system.systemUUID = lib.mkDefault (
      if builtins.getEnv "SYSTEM_UUID" != ""
      then builtins.getEnv "SYSTEM_UUID"
      else "unknown"
    );
  };
}
