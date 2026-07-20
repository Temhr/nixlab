{self, ...}: {
  flake.nixosModules.nsops--hermes = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.nixlab-hermes;
  in {
    imports = [self.nixosModules.servc--hermes-nixlab];
    options.services.nixlab-hermes.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./hermes.env;
      defaultText = lib.literalExpression "./hermes.env";
      description = ''
        Path to the sops-encrypted, dotenv-format env file for hermes-agent.
        This is the single source of truth for ALL messaging/LLM secrets,
        including Matrix's MATRIX_HOMESERVER, MATRIX_USER_ID,
        MATRIX_PASSWORD, and MATRIX_ALLOWED_USERS — see the implementation
        guide for the exact keys to add.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.HERMES_ENV = {
        sopsFile = cfg.secretsFile;
        format = "dotenv";
        restartUnits = ["hermes-agent.service"];
      };
      services.nixlab-hermes.messagingEnvFile = config.sops.secrets.HERMES_ENV.path;

      sops.secrets.HERMES_DASHBOARD_HTPASSWD = lib.mkIf cfg.dashboard.basicAuth.enable {
        sopsFile = ./hermes-dashboard.htpasswd;
        format = "binary";
        owner = "nginx";
        restartUnits = ["nginx.service"];
      };
      services.nixlab-hermes.dashboard.basicAuth.htpasswdFile =
        lib.mkIf cfg.dashboard.basicAuth.enable config.sops.secrets.HERMES_DASHBOARD_HTPASSWD.path;
    };
  };
}
