{...}: {
  flake.nixosModules.nsops--grafana = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.grafana-nixlab;
  in {
    imports = [self.nixosModules.servc--grafana-nixlab];

    options.services.grafana-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./grafana.yaml;
      defaultText = lib.literalExpression "./grafana.yaml";
      description = ''
        Path to the sops-encrypted grafana secrets file.
        Defaults to grafana.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets = let
        common = {
          sopsFile = cfg.secretsFile;
          owner = cfg.user;
          group = cfg.group;
          restartUnits = ["grafana.service"];
        };
      in {
        GRAFANA_ADMIN_PASSWORD = common;
        GRAFANA_SECRET_KEY = common;
      };

      # Wire the decrypted files into the service module.
      services.grafana-nixlab = {
        credentialsFile = lib.mkDefault config.sops.secrets.GRAFANA_ADMIN_PASSWORD.path;
        secretKeyFile = lib.mkDefault config.sops.secrets.GRAFANA_SECRET_KEY.path;
      };
    };
  };
}
