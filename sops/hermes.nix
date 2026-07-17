{...}: {
  flake.nixosModules.nsops--hermes = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.nixlab-hermes;
  in {
    imports = [self.nixosModules.servc--hermes-nixlab];
    options.services.nixlab-hermes.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./hermes.env; # was ./hermes.yaml
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.HERMES_ENV = {
        sopsFile = cfg.secretsFile;
        format = "dotenv";
        restartUnits = ["hermes-agent.service"];
      };
      services.nixlab-hermes.telegramEnvFile = config.sops.secrets.HERMES_ENV.path;
    };
  };
}
