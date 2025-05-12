{ config, lib, pkgs, ... }: {

  systemd.services.daily-git-commit = {
    description = "Daily Nix Flake Update and Git Commit Service";

    # Run daily at midnight
    startAt = "00:00";

    serviceConfig = {
      Type = "oneshot";
      User = "temhrbot";

      # Explicit path to the repository in temhr's home directory
      WorkingDirectory = "/home/temhr/nixlab";
    };

    script = ''
      # Run nix flake update
      ${pkgs.nix}/bin/nix flake update --flake /home/temhr/nixlab

      # Set git configuration for the service
      ${pkgs.git}/bin/git config user.name "temhrbot"
      ${pkgs.git}/bin/git config user.email "temhrbot@example.com"

      # Add all changes
      ${pkgs.git}/bin/git add .

      # Commit with a timestamp
      ${pkgs.git}/bin/git commit -m "Automated flake update: $(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')" || true

      # Push to the default branch (typically main or master)
      ${pkgs.git}/bin/git push origin HEAD
    '';
  };

  # Ensure SSH is configured for GitHub access
  # You'll need to manually set up SSH key authentication
  environment.systemPackages = with pkgs; [
    ssh-copy-id  # Helpful for setting up SSH key
  ];
}

/*

SSH Key Authentication:

1) You'll need to manually set up SSH key authentication for temhrbot:
    $ sudo -u temhrbot ssh-keygen -t ed25519 -C "temhrbot@example.com"
2) Add the generated public key to GitHub repository deploy keys or user SSH keys

# Set ACLs on temhr's home directory for temhrbot
    $ setfacl -R -m u:temhrbot:rwX /home/temhr
    $ setfacl -dR -m u:temhrbot:rwX /home/temhr

*/
