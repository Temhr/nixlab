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

      # GitHub nixlab repository automation key
      githubNixlabKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deploy the GitHub nixlab repository SSH key for automation";
        };

        symlinkToHome = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Create symlink in ~/.ssh/ for interactive git use";
        };
      };

      # Personal client key for SSH into remote servers
      clientPrivateKey = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deploy personal SSH private key for accessing remote servers";
        };

        symlinkToHome = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Create symlink in ~/.ssh/ for OpenSSH client usage";
        };

        # Optional: key name in secrets file (defaults to id_ed25519)
        secretName = lib.mkOption {
          type = lib.types.str;
          default = "id_ed25519";
          description = "Name of the key in the sops secrets file";
        };

        # Optional: symlink name (defaults to id_ed25519)
        symlinkName = lib.mkOption {
          type = lib.types.str;
          default = "id_ed25519";
          description = "Name for the symlink in ~/.ssh/ (e.g., id_ed25519, id_rsa)";
        };

        # Optional: SSH config entries for this key
        sshConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          example = ''
            Host homeserver
              HostName 10.0.1.100
              User admin
              IdentityFile ~/.ssh/id_ed25519

            Host *.myservers.com
              User myusername
              IdentityFile ~/.ssh/id_ed25519
          '';
          description = "SSH client config entries for hosts using this key";
        };
      };
    };

    config = lib.mkMerge [
      # Global sops-nix configuration
      (lib.mkIf cfg.enable {
        sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      })

      # GitHub nixlab repository key
      (lib.mkIf (cfg.enable && cfg.githubNixlabKey.enable) {
        sops.secrets."ssh-keys/id_github" = {
          sopsFile = cfg.secretsFile;
          key = "id_github";
          path = "/run/secrets/ssh_key_github";
          owner = mainUser;
          group = userConfig.group;
          mode = "0400";
        };
      })

      # Symlink for nixlab key
      (lib.mkIf (cfg.enable && cfg.githubNixlabKey.enable && cfg.githubNixlabKey.symlinkToHome) {
        systemd.tmpfiles.rules = [
          "d /run/secrets 0755 root root -"
          "L+ /home/${mainUser}/.ssh/id_github - ${mainUser} ${userConfig.group} - /run/secrets/ssh_key_github"
        ];
      })

      # Personal client SSH private key
      (lib.mkIf (cfg.enable && cfg.clientPrivateKey.enable) {
        sops.secrets."ssh-keys/${cfg.clientPrivateKey.secretName}" = {
          sopsFile = cfg.secretsFile;
          key = cfg.clientPrivateKey.secretName;
          path = "/run/secrets/ssh_key_${cfg.clientPrivateKey.secretName}";
          owner = mainUser;
          group = userConfig.group;
          mode = "0400";
        };
      })

      # Symlink for client private key
      (lib.mkIf (cfg.enable && cfg.clientPrivateKey.enable && cfg.clientPrivateKey.symlinkToHome) {
        systemd.tmpfiles.rules = [
          "d /run/secrets 0755 root root -"
          "L+ /home/${mainUser}/.ssh/${cfg.clientPrivateKey.symlinkName} - ${mainUser} ${userConfig.group} - /run/secrets/ssh_key_${cfg.clientPrivateKey.secretName}"
        ];
      })

      # SSH client config for the personal key
      (lib.mkIf (cfg.enable && cfg.clientPrivateKey.enable && cfg.clientPrivateKey.sshConfig != "") {
        programs.ssh.extraConfig = cfg.clientPrivateKey.sshConfig;
      })
    ];
  };
}
