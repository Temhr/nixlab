# This is a Nix module that sets up a systemd user service + timer
# to automatically run a git pull every hour.

{ pkgs, ... }:  # Import the package set (pkgs) and any other module arguments.
let
  # Define a shell script using Nix's `writeShellScript`.
  # This creates an executable script named "auto-git-pull" in the Nix store,
  # whose contents are read from your local file at ../files/scripts/auto-git-pull.sh.
  GitPullShellScript = pkgs.writeShellScript "auto-git-pull" (
    builtins.readFile ../files/scripts/auto-git-pull.sh
  );
in
{
  # Define a systemd user timer named `git-pull`.
  systemd."temhr".timers.git-pull = {
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
      WantedBy = [ "timers.target" ];
    };
  };

  # Define the systemd user service that the timer triggers.
  systemd."temhr".services.git-pull = {
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
    };
  };
}

#below to check status of .timer or .service
#systemctl --user status git-pull.timer
