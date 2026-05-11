# This is a Nix module that sets up a systemd user service + timer
# to automatically run a git pull every hour.
{pkgs, ...}:
# Import the package set (pkgs) and any other module arguments.
let
  # Define a shell script using Nix's `writeShellScript`.
  # This creates an executable script named "auto-git-pull" in the Nix store,
  # with the script content embedded directly in this file.
  GitPullShellScript = pkgs.writeShellScript "auto-git-pull" ''
    #!/usr/bin/env bash

    ## Exit on error
    set -e

    # 1) Navigates to the Flake directory
    # 2) Pulls the latest changes from the Git repository using the specified user

    ## Git Repository Updates
    cd "/home/temhr/nixlab" || exit 1

    echo "Pulling the latest version of the repository..."
    /run/wrappers/bin/sudo -u "temhr" GIT_SSH_COMMAND="/run/current-system/sw/bin/ssh -i /home/temhr/.ssh/id_flake_update -o BatchMode=yes -o StrictHostKeyChecking=no" /run/current-system/sw/bin/git pull --rebase

    ## Exit on Success
    exit 0
  '';
in {
  # Define a systemd user timer named `git-pull`.
  systemd.user.timers.git-pull = {
    Unit = {
      # This is metadata for the timer unit, a human-readable description.
      Description = "Run git pull every hour";
    };
    Timer = {
      # Start 1 minute after boot.
      OnBootSec = "1min";
      # Then re-run every 60 minutes.
      OnUnitActiveSec = "60min";
      # Specify which service unit the timer triggers.
      # Here, we tell the timer to trigger the `git-pull.service`.
      Unit = "git-pull.service";
    };
    Install = {
      # This makes the timer automatically start when the user session starts.
      # It "wants" the timer to be part of `timers.target`, which is like a group of timers.
      WantedBy = ["timers.target"];
    };
  };

  # Define the systemd user service that the timer triggers.
  systemd.user.services.git-pull = {
    Unit = {
      # Description of the service (for `systemctl status` etc.)
      Description = "Hourly nixlab git pull (user service)";
    };
    Service = {
      # Set the command to run.
      # We reference the script we defined earlier, which Nix has built and stored in its store.
      ExecStart = "${GitPullShellScript}";
      # The service type is "oneshot", meaning it runs the script once and exits.
      Type = "oneshot";
      # Add PATH so ssh and other commands are available
      Environment = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin";
    };
  };
}
# Below to check status of .timer or .service:
# systemctl --user status git-pull.timer
# systemctl --user status git-pull.service
