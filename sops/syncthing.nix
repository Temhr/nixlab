{ ... }: {
  flake.nixosModules.nsops--syncthing = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.syncthing-nixlab;
  in {
    options.services.syncthing-nixlab.secretsFile = lib.mkOption {
      type    = lib.types.path;
      default = ./syncthing.yaml;
      defaultText = lib.literalExpression "./syncthing.yaml";
      description = ''
        Path to the sops-encrypted syncthing secrets file.
        The file must be encrypted in binary format and contain a KEY=value
        env file with the following variables:
          SYNCTHING_GUI_USER=your-username
          SYNCTHING_GUI_PASSWORD_HASH=$2y$10$...your-bcrypt-hash...
          SYNCTHING_API_KEY=your-api-key

        Generate a bcrypt hash for your password

        Encrypt the file:
          sops --encrypt secrets/syncthing-env > secrets/syncthing.yaml

        Defaults to syncthing.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.enableGuiAuth;
          message = ''
            nsops--syncthing is imported but enableGuiAuth is disabled.
            Either:
            1. Set services.syncthing-nixlab.enableGuiAuth = true;
            2. Remove the nsops--syncthing module import (no secrets needed)
          '';
        }
      ];

      # Declare a single binary secret — the file content IS the env file.
      # sops-nix decrypts it to a path before any service starts.
      sops.secrets.syncthing-env = {
        sopsFile    = cfg.secretsFile;
        format      = "binary";
        owner       = cfg.user;
        group       = cfg.group;
        # Restart syncthing when the secret is rotated
        restartUnits = [ "syncthing.service" ];
      };

      # Wire the decrypted env file path directly to the service module.
      # The main syncthing module reads this and passes it to EnvironmentFile.
      services.syncthing-nixlab.secretsEnvFile =
        config.sops.secrets.syncthing-env.path;
    };
  };
}
