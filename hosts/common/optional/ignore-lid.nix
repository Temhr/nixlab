# ignore-lid.nix
#
# A fully self-contained NixOS module that ensures:
#   1. Closing the laptop lid NEVER suspends, hibernates, locks, or affects the system.
#   2. Behavior is controlled at the SYSTEM level — not user, DE, or session dependent.
#   3. Optional hard-disable of all suspend/hibernate targets to ensure nothing can sleep the machine.
#
{ config, lib, pkgs, ... }:
let
  cfg = config.services.ignoreLid;
in {
  ###### ─────────────────────────────────────────────────────────────
  # 1. MODULE OPTIONS
  ###### ─────────────────────────────────────────────────────────────
  options.services.ignoreLid = {
    enable = lib.mkEnableOption ''
      Ignore laptop lid events at the system level and prevent
      systemd-logind from suspending or acting on lid closure.
    '';

    disableSleepTargets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If true, masks systemd sleep targets (suspend.target, hibernate.target,
        hybrid-sleep.target, suspend-then-hibernate.target) and configures
        systemd-sleep to refuse all sleep modes. This prevents *any* mechanism
        from suspending the system.
      '';
    };
  };

  ###### ─────────────────────────────────────────────────────────────
  # 2. MODULE IMPLEMENTATION
  ###### ─────────────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {

    #### systemd-logind: authoritative lid behavior controller ####
    #
    # These values override all power-management rules at the OS level.
    # DEs (GNOME/KDE), home-manager, upower, and logind inhibitors
    # CANNOT override "ignore".
    #
    services.logind = {
      lidSwitch = "ignore";                    # lid close: do nothing
      lidSwitchDocked = "ignore";              # lid close when docked (unreliable detection)
      lidSwitchExternalPower = "ignore";       # lid close on AC power

      # Extra hardening: prevent these actions system-wide
      extraConfig = ''
        HandleSuspendKey=ignore
        HandleHibernateKey=ignore
        HandleLidSwitch=ignore
        HandleLidSwitchDocked=ignore
        HandleLidSwitchExternalPower=ignore
      '';
    };

    #### Optional: disable all sleep mechanisms in systemd ####
    #
    # This prevents:
    #   - systemctl suspend
    #   - systemctl hibernate
    #   - any process triggering sleep via org.freedesktop.login1
    #   - any DE power button mapping
    #
    systemd = lib.mkIf cfg.disableSleepTargets {
      # Mask all sleep-related targets so they cannot be activated
      targets.sleep.enable = false;
      targets.suspend.enable = false;
      targets.hibernate.enable = false;
      targets."hybrid-sleep".enable = false;
      targets."suspend-then-hibernate".enable = false;

      # Configure systemd-sleep to disable all sleep modes
      # This is the /etc/systemd/sleep.conf configuration
      sleep.extraConfig = ''
        [Sleep]
        AllowSuspend=no
        AllowHibernation=no
        AllowSuspendThenHibernate=no
        AllowHybridSleep=no
      '';
    };

    #### Extra: Prevent UPower from auto-suspending ####
    #
    # UPower can trigger suspend on critical battery.
    # This disables that behavior.
    #
    services.upower = lib.mkIf cfg.disableSleepTargets {
      enable = true;
      criticalPowerAction = "PowerOff";  # Or "HybridSleep" -> but we want nothing
      ignoreLid = true;
    };

    #### Safety note ####
    #
    # This module provides MAXIMUM protection against sleep.
    # To re-enable suspend:
    #
    #   services.ignoreLid.disableSleepTargets = false;
    #
    # Or disable the module entirely:
    #
    #   services.ignoreLid.enable = false;
  };
}
