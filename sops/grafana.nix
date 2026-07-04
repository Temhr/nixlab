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
      sops.secrets.GRAFANA_ADMIN_PASSWORD = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["grafana.service"];
      };
    };
  };
}
