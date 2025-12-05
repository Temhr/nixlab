# ignore-lid.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.services.ignoreLid;
in {
  options.services.ignoreLid = {
    enable = lib.mkEnableOption "Ignore laptop lid events at the system level";

    disableSleepTargets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable all systemd sleep targets system-wide";
    };
  };

  config = lib.mkIf cfg.enable {
    # systemd-logind: ignore all lid events
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };

    # Optional: disable all sleep mechanisms
    systemd = lib.mkIf cfg.disableSleepTargets {
      targets.sleep.enable = false;
      targets.suspend.enable = false;
      targets.hibernate.enable = false;
      targets."hybrid-sleep".enable = false;
      targets."suspend-then-hibernate".enable = false;

      sleep.extraConfig = ''
        [Sleep]
        AllowSuspend=no
        AllowHibernation=no
        AllowSuspendThenHibernate=no
        AllowHybridSleep=no
      '';
    };

    # Prevent UPower from auto-suspending on critical battery
    services.upower = lib.mkIf cfg.disableSleepTargets {
      enable = true;
      criticalPowerAction = "PowerOff";
      ignoreLid = true;
    };
  };
}
