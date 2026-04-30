{...}: {
  flake.nixosModules.nsops--bookstack = {
    config,
    flakePath,
    lib,
    ...
  }: let
    cfg = config.services.bookstack-nixlab;
  in {
    options.services.bookstack-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = flakePath + /secrets/bookstack.yaml;
      defaultText = lib.literalExpression "${flakePath}/secrets/bookstack.yaml";
      description = ''
        Path to the sops-encrypted bookstack secrets file.
        Defaults to bookstack.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      sops.secrets =
        lib.genAttrs
        ["MYSQL_ROOT_PASSWORD" "MYSQL_PASSWORD" "DB_PASS" "APP_KEY"]
        (_: {sopsFile = cfg.secretsFile;});
    };
  };
}
