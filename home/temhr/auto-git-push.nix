{ pkgs, ... }:
let
  auto-git-push = pkgs.writeShellScript "auto-move-files.sh" ''
      # Run nix flake update
      ${pkgs.nix}/bin/nix flake update --flake /home/temhr/nixlab

      # Set git configuration for the service
      /run/current-system/sw/bin/git config user.name "temhr"
      /run/current-system/sw/bin/git config user.email "9110264+Temhr@users.noreply.github.com"

      # Add all changes
      /run/current-system/sw/bin/git add .

      # Commit with a timestamp
      /run/current-system/sw/bin/git commit -m "Automated flake update: $(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')" || true

      # Push to the default branch (typically main or master)
      /run/current-system/sw/bin/git push origin HEAD
  '';
in
{
  systemd."temhr".timers.auto-git-push = {
    Unit = {
      Description = "Daily Nix Flake Update and Git Commit Service (timer)";
    };
    Timer = {
      OnCalendar = "daily"; # Runs once per day at midnight by default
      Persistent = true;
      Unit = "auto-git-push.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd."temhr".services.auto-git-push = {
    Unit = {
      Description = "Daily Nix Flake Update and Git Commit Service (user service)";
    };
    Service = {
      ExecStart = "${auto-git-push}";
      Type = "oneshot";
    };
  };
}
