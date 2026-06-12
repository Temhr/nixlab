{...}: {
  flake.nixosModules.hosts--autom--flake-update = {
    config,
    pkgs,
    ...
  }:
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
      # Use the sops-managed GitHub nixlab key with full paths
      GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /run/secrets/ssh_key_github_nixlab -o BatchMode=yes -o StrictHostKeyChecking=no" \
        ${pkgs.git}/bin/git pull --rebase

      # Update flake
      echo "Updating flake.lock..."
      ${pkgs.nix}/bin/nix flake update --flake /home/${config.nixlab.mainUser}/nixlab

      # Commit and push if there are changes
      if ! ${pkgs.git}/bin/git diff --quiet flake.lock; then
          echo "Changes detected in flake.lock, committing..."
          ${pkgs.git}/bin/git add flake.lock
          ${pkgs.git}/bin/git commit -m "$(${pkgs.nettools}/bin/hostname) - update flake.lock - $(${pkgs.coreutils}/bin/date)"

          echo "Pushing changes to remote..."
          GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /run/secrets/ssh_key_github_nixlab -o BatchMode=yes -o StrictHostKeyChecking=no" \
            ${pkgs.git}/bin/git push

          echo "Flake update completed and pushed successfully"
      else
          echo "No changes in flake.lock, nothing to commit"
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
      # Ensure secrets are available before running
      after = ["sops-nix.service" "network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        # Set the command to run.
        ExecStart = "${flakeUpdateShellScript}";
        Type = "oneshot";
        # Run as the temhr user
        User = config.nixlab.mainUser;
        # Set the working directory
        WorkingDirectory = "/home/${config.nixlab.mainUser}/nixlab";
        # Add PATH with all required binaries
        Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.git pkgs.openssh pkgs.nix pkgs.nettools pkgs.coreutils]}";
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

