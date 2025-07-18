{ pkgs, ... }:  # Import the package set (pkgs) and any other module arguments.
let
  flakeAutoUpdate = pkgs.writeShellScript "flakeAutoUpdate" (
    builtins.readFile ../files/scripts/auto-update-flake.sh
  );
in
{
  # Define a systemd user timer named `flake-auto-update`.
  systemd.user.timers.flake-auto-update = {
    Unit = {
      Description = "Timer for flake auto-update";
    };
    Timer = {
      # Run daily at times
      OnCalendar = [ "11:45" "23:45" ];
      # Add randomization delay of up to # hours
      RandomizedDelaySec = "1h";
      # Make the timer persistent across reboots
      Persistent = true;
      Unit = "flake-auto-update.service";
    };
    Install = {
      # This makes the timer automatically start when the user session starts.
      # It "wants" the timer to be part of `timers.target`, which is like a group of timers.
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.flake-auto-update = {
    Unit = {
      Description = "Update flake and push to remote";
    };
    Service = {
      # Set the command to run.
      ExecStart = "${flakeAutoUpdate}";
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
