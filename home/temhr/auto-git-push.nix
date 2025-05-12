{ config, lib, pkgs, ... }: {

  systemd.services.auto-git-push = {
    description = "Daily Nix Flake Update and Git Commit Service";

    # Run daily at midnight
    startAt = "00:00";

    serviceConfig = {
      Type = "oneshot";
      User = "temhr";

      # Explicit path to the repository in temhr's home directory
      WorkingDirectory = "/home/temhr/nixlab";
    };

    script = ''
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
  };

  # Ensure SSH is configured for GitHub access
  # You'll need to manually set up SSH key authentication
  environment.systemPackages = with pkgs; [
    ssh-copy-id  # Helpful for setting up SSH key
  ];
}
