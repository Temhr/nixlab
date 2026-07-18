{...}: {
  flake.nixosModules.nsops--matrix = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.matrix-nixlab;
  in {
    imports = [self.nixosModules.servc--matrix-nixlab];
    options.services.matrix-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./matrix.yaml;
      defaultText = lib.literalExpression "./matrix.yaml";
      description = ''
        Path to the sops-encrypted matrix secrets file.
        Defaults to matrix.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets =
        (lib.genAttrs
          ["MATRIX_HERMES-BOT_PASSWORD" "MATRIX_TEMHR_PASSWORD"]
          (_: {
            sopsFile = cfg.secretsFile;
            owner = "root";
            group = "root";
            restartUnits = ["matrix-nixlab-init-users.service"];
          }))
        // {
          MATRIX_REGISTRATION_TOKEN = {
            sopsFile = cfg.secretsFile;
            owner = "root";
            group = "matrix-nixlab-secrets";
            mode = "0440";
            restartUnits = ["continuwuity.service" "matrix-nixlab-init-users.service"];
          };
        };

      services.matrix-nixlab = {
        registrationTokenFile = config.sops.secrets.MATRIX_REGISTRATION_TOKEN.path;
        initUsers.enable = lib.mkDefault true;
        initUsers.accounts = [
          {
            username = "hermes-bot";
            passwordFile = config.sops.secrets.MATRIX_HERMES-BOT_PASSWORD.path;
          }
          {
            username = "temhr";
            passwordFile = config.sops.secrets.MATRIX_TEMHR_PASSWORD.path;
          }
        ];
      };
    };
  };
}
