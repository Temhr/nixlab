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
    cfg = config.nixlab.ssh-keys;
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

      # Nixlab's github key options
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

    # Global sops-nix configuration (only when module is enabled)
    config.sops.age.keyFile = lib.mkIf cfg.enable "/var/lib/sops-nix/key.txt";

    # GitHub nixlab repository key - encapsulated config
    config.sops.secrets."ssh-keys/id_github_nixlab" = lib.mkIf (cfg.enable && cfg.githubNixlabKey.enable) {
      sopsFile = cfg.secretsFile;
      key = "id_github_nixlab";
      path = "/run/secrets/ssh_key_github_nixlab";
      owner = mainUser;
      group = userConfig.group;
      mode = "0400";
    };

    # Symlink for nixlab key - encapsulated config
    config.systemd.tmpfiles.rules = lib.mkIf (cfg.enable && cfg.githubNixlabKey.enable && cfg.githubNixlabKey.symlinkToHome) [
      "d /run/secrets 0755 root root -"
      "L+ /home/${mainUser}/.ssh/id_github_nixlab - ${mainUser} ${userConfig.group} - /run/secrets/ssh_key_github_nixlab"
    ];

    # GitHub key (optional, for other GitHub repos) - encapsulated config
    config.sops.secrets."ssh-keys/id_github" = lib.mkIf (cfg.enable && cfg.githubKey.enable) {
      sopsFile = cfg.secretsFile;
      key = "id_github";
      path = "/run/secrets/ssh_key_github";
      owner = mainUser;
      group = userConfig.group;
      mode = "0400";
    };

    # Backup SSH key (optional) - encapsulated config
    config.sops.secrets."ssh-keys/id_backup" = lib.mkIf (cfg.enable && cfg.backupKey.enable) {
      sopsFile = cfg.secretsFile;
      key = "id_backup";
      path = "/run/secrets/ssh_key_backup";
      owner = mainUser;
      group = userConfig.group;
      mode = "0400";
    };
  };
}
