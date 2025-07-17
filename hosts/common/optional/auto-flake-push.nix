{ config, lib, pkgs, ... }:

let
  cfg = config.flakeLock;
in {
  options = {
    flakeLock = {
      autoPush = lib.mkOption {
        type = lib.types.enum [ "no" "yes" ];
        default = "no";
        description = "Run flake update every 8 hours";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.autoPush == "yes") {

      systemd.services.flake-update = {
        description = "Update flake and push to GitHub";
        serviceConfig = {
          Type = "oneshot";
          User = "temhr";  # Replace with your username
          WorkingDirectory = "/home/temhr/nixlab";
          Environment = [
            "PATH=${pkgs.lib.makeBinPath [ pkgs.nix pkgs.git ]}"
            "HOME=/home/temhr"
            "SSH_AUTH_SOCK=/run/user/1000/keyring/ssh"  # Adjust UID if needed
          ];
        };
        script = ''
          set -e

          # Pull from remote
          git pull

          # Update the flake
          nix flake update --flake /home/temhr/nixlab

          # Check if there are any changes
          if ! git diff --quiet flake.lock; then
            # Stage and commit the changes
            git add flake.lock
            git commit -m "Auto-update flake.lock $(date)"

            # Push to remote
            git push

            echo "Flake updated and pushed successfully"
          else
            echo "No changes to flake.lock, skipping push"
          fi
        '';
      };

      systemd.timers.flake-update = {
        description = "Run flake update every 8 hours";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/8:00";  # Every 8 hours
          Persistent = false;        # Run missed timers on boot
          RandomizedDelaySec = "30m"; # Add some randomization to avoid load spikes
        };
      };

    })
  ];
}
