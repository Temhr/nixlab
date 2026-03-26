{
  config,
  lib,
  ...
}: {
  options.services.bookstack-custom.secretsFile = lib.mkOption {
    type = lib.types.path;
    default = ../../../secrets/bookstack.yaml;
    description = "Path to sops-encrypted bookstack secrets";
  };

  config = {
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";

    sops.secrets =
      lib.genAttrs
      ["MYSQL_ROOT_PASSWORD" "MYSQL_PASSWORD" "DB_PASS" "APP_KEY"]
      (_: {sopsFile = config.services.bookstack-custom.secretsFile;});
  };
}
