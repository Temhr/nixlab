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
        ["BOOKSTACK_MYSQL_ROOT_PASSWORD" "BOOKSTACK_MYSQL_PASSWORD" "BOOKSTACK_DB_PASSWORD" "BOOKSTACK_APP_KEY"]
        (_: {
          sopsFile = cfg.secretsFile;
          owner = "root";
          group = "root";
          restartUnits = ["podman-bookstack.service" "podman-bookstack-db.service"];
        });
    };
  };
}
