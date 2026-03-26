{ config, lib, ... }: {

  options.services.grafana-custom.secretsFile = lib.mkOption {
    type        = lib.types.path;
    default     = ../../../secrets/grafana.yaml;
    description = "Path to the sops-encrypted grafana secrets file";
  };

  config = lib.mkIf config.services.grafana-custom.enable {
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";

    sops.secrets.GF_SECURITY_ADMIN_PASSWORD = {
      sopsFile = config.services.grafana-custom.secretsFile;
    };
  };
}
