# Self-registering secret module for SSH private keys
# Manages GitHub SSH key for nixlab repository access
{...}: {
  flake.nixosModules.nsops--ssh-keys = {
    config,
    lib,
    ...
  }: let
    # Get the main user from nixlab.mainUser option
    mainUser = config.nixlab.mainUser;
    userConfig = config.users.users.${mainUser};
  in {
    # Define options for SSH key management
    options.nixlab.ssh-keys = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH key management via sops-nix";
      };

      secretsFile = lib.mkOption {
        type = lib.types.path;
        default = ./ssh-keys.yaml;
        description = "Path to sops-encrypted SSH keys file";
      };

      githubNixlabKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deploy the GitHub nixlab repository SSH key";
        };

        symlinkToHome = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Create symlink in ~/.ssh/ for interactive git use";
        };
      };

      githubKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy a separate GitHub SSH key (for other repos)";
        };
      };

      backupKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy the backup SSH key";
        };
      };
    };

    config = lib.mkIf config.nixlab.ssh-keys.enable {
      # Configure sops-nix age key location
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      # GitHub nixlab repository key (main key for accessing temhr/nixlab)
      sops.secrets."ssh-keys/id_github_nixlab" = lib.mkIf config.nixlab.ssh-keys.githubNixlabKey.enable {
        sopsFile = config.nixlab.ssh-keys.secretsFile;
        key = "id_github_nixlab";
        path = "/run/secrets/ssh_key_github_nixlab";
        owner = mainUser;
        group = userConfig.group;
        mode = "0400";
      };

      # GitHub key (optional, for other GitHub repos)
      sops.secrets."ssh-keys/id_github" = lib.mkIf config.nixlab.ssh-keys.githubKey.enable {
        sopsFile = config.nixlab.ssh-keys.secretsFile;
        key = "id_github";
        path = "/run/secrets/ssh_key_github";
        owner = mainUser;
        group = userConfig.group;
        mode = "0400";
      };

      # Backup SSH key (optional)
      sops.secrets."ssh-keys/id_backup" = lib.mkIf config.nixlab.ssh-keys.backupKey.enable {
        sopsFile = config.nixlab.ssh-keys.secretsFile;
        key = "id_backup";
        path = "/run/secrets/ssh_key_backup";
        owner = mainUser;
        group = userConfig.group;
        mode = "0400";
      };

      # Create symlink in ~/.ssh/ for interactive git operations
      # This allows "git pull" to work from the command line
      systemd.tmpfiles.rules = lib.mkIf (config.nixlab.ssh-keys.githubNixlabKey.enable && config.nixlab.ssh-keys.githubNixlabKey.symlinkToHome) [
        "d /run/secrets 0755 root root -"
        "L+ /home/${mainUser}/.ssh/id_github_nixlab - ${mainUser} ${userConfig.group} - /run/secrets/ssh_key_github_nixlab"
      ];
    };
  };
}
