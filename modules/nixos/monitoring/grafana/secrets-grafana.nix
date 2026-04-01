{...}: {
  flake.nixosModules.secrets--grafana = {
    config,
    lib,
    ...
  }: {
    options.services.grafana-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./grafana.yaml;
      defaultText = lib.literalExpression "./grafana.yaml";
      description = ''
        Path to the sops-encrypted grafana secrets file.
        Defaults to grafana.yaml co-located with this module.
        Override per-host if needed.
      '';

    config = lib.mkIf config.services.grafana-nixlab.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.GF_SECURITY_ADMIN_PASSWORD = {
        sopsFile = config.services.grafana-nixlab.secretsFile;
      };
    };
  };
}
