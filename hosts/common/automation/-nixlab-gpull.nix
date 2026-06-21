# This is a Nix module that sets up a systemd system service + timer
# to automatically run a git pull every hour.
{...}: {
  flake.nixosModules.hosts--autom--nixlab-gpull = {
    config,
    pkgs,
    ...
  }:
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
      # Use the sops-managed GitHub nixlab key
      GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /run/secrets/ssh_key_github -o BatchMode=yes -o StrictHostKeyChecking=no" \
        ${pkgs.git}/bin/git pull --rebase

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
      # Ensure secrets are available before running
      after = ["sops-nix.service"];
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
        # Add PATH so commands are available
        Environment = "PATH=${pkgs.lib.makeBinPath [pkgs.git pkgs.openssh]}";
      };
    };
  };
}
# Below to check status of .timer or .service:
# systemctl status nixlab-gpull.timer
# systemctl status nixlab-gpull.service

