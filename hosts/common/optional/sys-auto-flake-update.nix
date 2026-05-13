{config, ...}: {
  flake.nixosModules.systm--auto-flake-update = {pkgs, ...}:
  # Import the package set (pkgs) and any other module arguments.
  let
    flakeUpdateShellScript = pkgs.writeShellScript "flakeUpdate" ''
      #!/usr/bin/env bash

      ## Exit on error
      set -e

      # 1) Navigates to the Flake directory
      # 2) Pulls the latest changes from the Git repository

      ## Git Repository Updates
      cd "/home/${config.nixlab.mainUser}/nixlab" || exit 1

      echo "Pulling the latest version of the repository..."
      GIT_SSH_COMMAND="ssh -i /run/secrets/ssh_key_flake_update -o BatchMode=yes -o StrictHostKeyChecking=no" /run/current-system/sw/bin/git pull --rebase

      # Update flake
      nix flake update --flake /home/${config.nixlab.mainUser}/nixlab

      # Commit and push if there are changes
      if ! /run/current-system/sw/bin/git diff --quiet flake.lock; then
          /run/current-system/sw/bin/git add flake.lock
          /run/current-system/sw/bin/git commit -m "$(hostname) - update flake.lock - $(date)"
          GIT_SSH_COMMAND="ssh -i /run/secrets/ssh_key_flake_update -o BatchMode=yes -o StrictHostKeyChecking=no" /run/current-system/sw/bin/git push
      fi

      ## Exit on Success
      exit 0
    '';
  in {
    # Define a systemd system timer named `flake-update`.
    systemd.timers.flake-update = {
      description = "Timer for flake auto-update";
      wantedBy = ["timers.target"];
      timerConfig = {
        # Run daily at times
        OnCalendar = "23:40";
        # Add randomization delay of up to 1 hour
        RandomizedDelaySec = "1h";
        # Make the timer persistent across reboots
        Persistent = false;
        Unit = "flake-update.service";
      };
    };

    systemd.services.flake-update = {
      description = "Update flake and push to remote";
      serviceConfig = {
        # Set the command to run.
        ExecStart = "${flakeUpdateShellScript}";
        Type = "oneshot";
        # Run as the temhr user
        User = config.nixlab.mainUser;
        # Set the working directory
        WorkingDirectory = "/home/${config.nixlab.mainUser}/nixlab";
        # ⏲ Add a timeout: stop after 5 minutes (adjust as needed)
        TimeoutStartSec = "5min";
        # Optionally kill all subprocesses if this times out
        KillMode = "process";
      };
    };
  };
}
# Commands to check status:
# systemctl status flake-update.timer
# systemctl status flake-update.service
#
# To see when the timer will next run:
# systemctl list-timers flake-update.timer
#
# To manually trigger the service:
# systemctl start flake-update.service

