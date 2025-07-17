{ config, lib, pkgs, ... }:

let
  cfg = config.services.flakeAutoUpdate;
in {
  options.services.flakeAutoUpdate = {
    enable = lib.mkEnableOption "automatic flake updates";

    user = lib.mkOption {
      type = lib.types.str;
      default = "temhr";
      description = "User to run the service as";
    };

    flakePath = lib.mkOption {
      type = lib.types.path;
      default = "/home/temhr/nixlab";
      description = "Path to the flake directory";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/8:00";
      description = "Systemd timer interval";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.flake-auto-update = {
      description = "Update flake and push to remote";
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = cfg.flakePath;
        Environment = [
          "PATH=${pkgs.lib.makeBinPath [ pkgs.nix pkgs.git ]}"
          "HOME=/home/${cfg.user}"
        ];
      };

      script = ''
        set -e

        # Pull from remote
        git pull --rebase

        # Update flake
        nix flake update

        # Commit and push if there are changes
        if ! git diff --quiet flake.lock; then
          git add flake.lock
          git commit -m "Auto-update flake.lock"
          git push
        fi
      '';
    };

    systemd.user.timers.flake-auto-update = {
      description = "Timer for flake auto-update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };

    users.users.${cfg.user}.linger = true;
  };
}
