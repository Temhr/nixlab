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
      # Run daily at a random time between 22:00 and 24:00 (2 hour window)
      OnCalendar = "20:00";
      # Add randomization delay of up to 2 hours (7200 seconds)
      RandomizedDelaySec = "4h";
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
