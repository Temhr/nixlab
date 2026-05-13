{pkgs, ...}:
# Import the package set (pkgs) and any other module arguments.
let
  flakeAutoUpdateShellScript = pkgs.writeShellScript "flakeAutoUpdate" ''
    #!/usr/bin/env bash

    ## Exit on error
    set -e

    # 1) Navigates to the Flake directory
    # 2) Pulls the latest changes from the Git repository using the specified user

    ## Git Repository Updates
    cd "/home/temhr/nixlab" || exit 1

    echo "Pulling the latest version of the repository..."
    /run/wrappers/bin/sudo -u "temhr" GIT_SSH_COMMAND="ssh -i /run/secrets/ssh_key_flake_update -o BatchMode=yes -o StrictHostKeyChecking=no" /run/current-system/sw/bin/git pull --rebase

    # Update flake
    /run/wrappers/bin/sudo -u "temhr" nix flake update --flake /home/temhr/nixlab

    # Commit and push if there are changes
    if ! /run/current-system/sw/bin/git diff --quiet flake.lock; then
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/git add flake.lock
        /run/wrappers/bin/sudo -u "temhr" /run/current-system/sw/bin/git commit -m "$(hostname) - update flake.lock - $(date)"
        /run/wrappers/bin/sudo -u "temhr" GIT_SSH_COMMAND="ssh -i /run/secrets/ssh_key_flake_update -o BatchMode=yes -o StrictHostKeyChecking=no" /run/current-system/sw/bin/git push
    fi

    ## Exit on Success
    exit 0
  '';
in {
  # Define a systemd user timer named `flake-auto-update`.
  systemd.user.timers.flake-auto-update = {
    Unit = {
      Description = "Timer for flake auto-update";
    };
    Timer = {
      # Run daily at times
      OnCalendar = ["23:40"];
      # Add randomization delay of up to # hours
      RandomizedDelaySec = "1h";
      # Make the timer persistent across reboots
      Persistent = false;
      Unit = "flake-auto-update.service";
    };
    Install = {
      # This makes the timer automatically start when the user session starts.
      # It "wants" the timer to be part of `timers.target`, which is like a group of timers.
      WantedBy = ["timers.target"];
    };
  };

  systemd.user.services.flake-auto-update = {
    Unit = {
      Description = "Update flake and push to remote";
    };
    Service = {
      # Set the command to run.
      ExecStart = "${flakeAutoUpdateShellScript}";
      Type = "oneshot";

      # ⏲ Add a timeout: stop after 5 minutes (adjust as needed)
      TimeoutStartSec = "5min";
      # Optionally kill all subprocesses if this times out
      KillMode = "process";
    };
  };
}
# Commands to check status:
# systemctl --user status flake-auto-update.timer
# systemctl --user status flake-auto-update.service
#
# To see when the timer will next run:
# systemctl --user list-timers flake-auto-update.timer
#
# To manually trigger the service:
# systemctl --user start flake-auto-update.service

