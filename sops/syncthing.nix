{...}: {
  flake.nixosModules.nsops--syncthing = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.syncthing-nixlab;
  in {
    options.services.syncthing-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./syncthing.yaml;
      defaultText = lib.literalExpression "./syncthing.yaml";
      description = ''
        Path to the sops-encrypted syncthing secrets file.
        Defaults to syncthing.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.syncthing-nixlab ? enable;
          message = "nsops--syncthing requires servc--syncthing-nixlab to also be imported";
        }
        {
          assertion = cfg.enableGuiAuth;
          message = ''
            nsops--syncthing is imported but GUI authentication is disabled.
            Either:
            1. Set services.syncthing-nixlab.enableGuiAuth = true;
            2. Remove the nsops--syncthing module import (no secrets needed)
          '';
        }
      ];

      # Declare individual secrets
      sops.secrets."syncthing/gui_user" = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["syncthing-secrets.service"];
      };

      sops.secrets."syncthing/gui_password_hash" = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["syncthing-secrets.service"];
      };

      sops.secrets."syncthing/api_key" = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["syncthing-secrets.service"];
      };

      # Wire decrypted secrets to service via environment file
      services.syncthing-nixlab.secretsEnvFile = "/run/syncthing-credentials.env";
    };
  };
}
