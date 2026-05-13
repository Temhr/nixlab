# This is a Nix module that sets up a systemd system service + timer
# to automatically run a git pull every hour.
{config, ...}: {
  flake.nixosModules.systm--auto-nixlab-gpull = {pkgs, ...}:
  # Import the package set (pkgs) and any other module arguments.
  let
    # Define a shell script using Nix's `writeShellScript`.
    # This creates an executable script named "nixlabGPull" in the Nix store,
    # with the script content embedded directly in this file.
    nixlabGPullShellScript = pkgs.writeShellScript "nixlabGPull" ''
      #!/usr/bin/env bash

      ## Exit on error
      set -e

      # 1) Navigates to the Flake directory
      # 2) Pulls the latest changes from the Git repository

      ## Git Repository Updates
      cd "/home/${config.nixlab.mainUser}/nixlab" || exit 1

      echo "Pulling the latest version of the repository..."
      GIT_SSH_COMMAND="/run/current-system/sw/bin/ssh -i /run/secrets/ssh_key_flake_update -o BatchMode=yes -o StrictHostKeyChecking=no" /run/current-system/sw/bin/git pull --rebase

      ## Exit on Success
      exit 0
    '';
  in {
    # Define a systemd system timer named `nixlab-gpull`.
    systemd.timers.nixlab-gpull = {
      description = "Run git pull every hour";
      wantedBy = ["timers.target"];
      timerConfig = {
        # Start 1 minute after boot.
        OnBootSec = "1min";
        # Then re-run every 60 minutes.
        OnUnitActiveSec = "60min";
        # Specify which service unit the timer triggers.
        Unit = "nixlab-gpull.service";
      };
    };

    # Define the systemd system service that the timer triggers.
    systemd.services.nixlab-gpull = {
      description = "Hourly nixlab git pull (system service)";
      serviceConfig = {
        # Set the command to run.
        # We reference the script we defined earlier, which Nix has built and stored in its store.
        ExecStart = "${nixlabGPullShellScript}";
        # The service type is "oneshot", meaning it runs the script once and exits.
        Type = "oneshot";
        # Run as the user
        User = config.nixlab.mainUser;
        # Set the working directory
        WorkingDirectory = "/home/${config.nixlab.mainUser}/nixlab";
        # Add PATH so ssh and other commands are available
        Environment = "PATH=/run/current-system/sw/bin";
      };
    };
  };
}
# Below to check status of .timer or .service:
# systemctl status nixlab-gpull.timer
# systemctl status nixlab-gpull.service

