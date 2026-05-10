{...}: {
  flake.nixosModules.nsops--grafana = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.grafana-nixlab;
  in {
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
      assertions = [
        {
          assertion = config.services.grafana-nixlab ? enable;
          message = "nsops--grafana requires servc--grafana-nixlab to also be imported";
        }
      ];

      sops.secrets.GF_SECURITY_ADMIN_PASSWORD = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
      };
    };
  };
}
