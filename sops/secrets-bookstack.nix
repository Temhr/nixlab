{...}: {
  flake.nixosModules.nsops--bookstack = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.bookstack-nixlab;
  in {
    options.services.bookstack-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./bookstack.yaml;
      defaultText = lib.literalExpression "./bookstack.yaml";
      description = ''
        Path to the sops-encrypted bookstack secrets file.
        Defaults to bookstack.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.bookstack-nixlab ? enable;
          message = "nsops--bookstack requires servc--bookstack-nixlab to also be imported";
        }
      ];

      sops.secrets =
        lib.genAttrs
        ["MYSQL_ROOT_PASSWORD" "MYSQL_PASSWORD" "DB_PASS" "APP_KEY"]
        (_: {
          sopsFile = cfg.secretsFile;
          restartUnits = ["bookstack.service"];
        });
    };
  };
}
