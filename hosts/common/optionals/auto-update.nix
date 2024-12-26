# This module implements automatic system updates for NixOS, replacing the built-in system.autoUpgrade
{ config, lib, ... }:

# Create a shorthand reference to the module's configuration options
let
  cfg = config.aux.system.services.autoUpgrade;
in
{
  # Define the configuration options for this module
  options = {
    aux.system.services.autoUpgrade = {
      # Basic enable/disable toggle for the auto-upgrade feature
      enable = lib.mkEnableOption "Enables automatic system updates.";
      # Specify where NixOS configuration files are stored
      configDir = lib.mkOption {
        type = lib.types.str;
        description = "Path where your NixOS configuration files are stored.";
      };

      # Allow passing additional command-line flags to nixos-rebuild
      extraFlags = lib.mkOption {
        type = lib.types.str;
        description = "Extra flags to pass to nixos-rebuild.";
        default = "";
      };

      # Configure update frequency using systemd timer syntax
      onCalendar = lib.mkOption {
        default = "daily";
        type = lib.types.str;
        description = "How frequently to run updates. See systemd.timer(5) and systemd.time(7) for configuration details.";
      };

      # Specify the type of update operation to perform
      operation = lib.mkOption {
        type = lib.types.enum [
          "boot"    # Apply updates on next boot
          "switch"  # Apply updates immediately
          "test"    # Test updates without applying
        ];
        default = "switch";
        description = "Which `nixos-rebuild` operation to perform. Defaults to `switch`.";
      };

      # Control whether missed updates should be run after system downtime
      persistent = lib.mkOption {
        default = true;
        type = lib.types.bool;
        description = "If true, the time when the service unit was last triggered is stored on disk. When the timer is activated, the service unit is triggered immediately if it would have been triggered at least once during the time when the timer was inactive. This is useful to catch up on missed runs of the service when the system was powered down.";
      };

      # Option to automatically update flake.lock and push changes
      pushUpdates = lib.mkEnableOption "Updates the flake.lock file and pushes it back to the repo.";

      # Specify the user who owns the configuration directory
      user = lib.mkOption {
        type = lib.types.str;
        description = "The user who owns the configDir.";
      };
    };
  };

  # Implementation of the module when enabled
  config = lib.mkIf cfg.enable {
    # Ensure this module doesn't conflict with built-in auto-upgrade
    assertions = [
      {
        assertion = !config.system.autoUpgrade.enable;
        message = "The system.autoUpgrade option conflicts with this module.";
      }
    ];

    # Enable the custom upgrade script
    aux.system.nixos-upgrade-script.enable = true;

    # Configure systemd to manage the automatic updates
    systemd = {
      # Define the service that performs the update
      services."nixos-upgrade" = {
        serviceConfig = {
          Type = "oneshot";     # Run once and exit
          User = "root";        # Must run as root
        };
        # Ensure necessary packages are available
        path = config.aux.system.corePackages;
        # Ensure the config directory is mounted before running
        unitConfig.RequiresMountsFor = cfg.configDir;
        # Construct the update command with conditional arguments
        script = lib.strings.concatStrings [
          # Base command with operation type
          "/run/current-system/sw/bin/nixos-upgrade-script --operation ${cfg.operation} "
          # Add flake directory if specified
          (lib.mkIf (cfg.configDir != "") "--flake ${cfg.configDir} ").content
          # Add user if specified
          (lib.mkIf (cfg.user != "") "--user ${cfg.user} ").content
          # Add update flag if pushUpdates is enabled
          (lib.mkIf (cfg.pushUpdates) "--update ").content
          # Add any extra flags
          (lib.mkIf (cfg.extraFlags != "") cfg.extraFlags).content
        ];
      };

      # Configure the timer that triggers the update service
      timers."nixos-upgrade" = {
        # Ensure network is available before running
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        # Enable the timer by default
        wantedBy = [ "timers.target" ];

        # Timer configuration
        timerConfig = {
          OnCalendar = cfg.onCalendar;          # When to run updates
          Persistent = cfg.persistent;           # Whether to run missed updates
          Unit = "nixos-upgrade.service";        # Service to trigger
          RandomizedDelaySec = "30m";           # Add random delay up to 30 minutes
        };
      };
    };
  };
}
