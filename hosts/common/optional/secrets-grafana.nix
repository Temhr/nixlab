{
  config,
  lib,
  ...
}: {
  options.services.grafana-nixlab.secretsFile = lib.mkOption {
    type = lib.types.path;
    default = ../../../secrets/grafana.yaml;
    description = "Path to the sops-encrypted grafana secrets file";
  };

  config = {
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";

    sops.secrets.GF_SECURITY_ADMIN_PASSWORD = {
      sopsFile = config.services.grafana-nixlab.secretsFile;
    };
  };
}
