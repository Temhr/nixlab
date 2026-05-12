# Self-registering secret module for SSH private keys
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

      flakeUpdateKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deploy the flake update SSH key";
        };
      };

      githubKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Deploy the GitHub SSH key";
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

      # Flake update SSH key
      sops.secrets."ssh-keys/id_flake_update" = lib.mkIf config.nixlab.ssh-keys.flakeUpdateKey.enable {
        sopsFile = config.nixlab.ssh-keys.secretsFile;
        key = "id_flake_update";
        path = "/run/secrets/ssh_key_flake_update";
        owner = mainUser;
        group = userConfig.group;
        mode = "0400";
        # Restart git-pull service when key changes (if it exists)
        restartUnits = lib.optional (config.systemd.user.services ? git-pull) "git-pull.service";
      };

      # GitHub SSH key (optional)
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

      # Ensure the secrets directory exists
      systemd.tmpfiles.rules = [
        "d /run/secrets 0755 root root -"
      ];
    };
  };
}
