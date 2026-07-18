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

      services.nixlab-hermes.matrix = {
        enable = true;
        login = {
          enable = true;
          username = "hermes-bot";
          passwordFile = config.sops.secrets.MATRIX_HERMES-BOT_PASSWORD.path;
        };
      };

      # Only wired up if dashboard.basicAuth.enable is actually set true
      # elsewhere — this just makes the htpasswd file available as a sops
      # secret and points the option at it. htpasswd is a plain file (not
      # dotenv/yaml), so no `format` conversion needed; nginx reads it
      # directly at request time, so it's never rendered into the Nix store.
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

