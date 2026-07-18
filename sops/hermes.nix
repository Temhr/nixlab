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
        restartUnits = ["hermes-agent.service" "hermes-matrix-login.service"];
      };
      services.nixlab-hermes.messagingEnvFile = config.sops.secrets.HERMES_ENV.path;

      services.nixlab-hermes.matrixLogin = {
        enable = true;
        username = "hermes-bot";
        passwordFile = config.sops.secrets.MATRIX_HERMES-BOT_PASSWORD.path;
      };
    };
  };
}
