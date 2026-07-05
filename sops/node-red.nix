{...}: {
  flake.nixosModules.nsops--node-red = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.nodered-service;
  in {
    imports = [self.nixosModules.servc--node-red-nixlab];
    # ══════════════════════════════════════════════════════════════════════════
    # OPTIONS
    # ══════════════════════════════════════════════════════════════════════════
    options.services.nodered-service.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./node-red.yaml;
      description = "Path to sops-encrypted secrets file";
    };

    # ══════════════════════════════════════════════════════════════════════════
    # CONFIG
    # ══════════════════════════════════════════════════════════════════════════
    config = lib.mkIf cfg.enable {
      # ────────────────────────────────────────────────────────────────────────
      # Declare secrets
      # ────────────────────────────────────────────────────────────────────────
      sops.secrets =
        lib.genAttrs
        ["NODE_RED_CREDENTIAL_SECRET"]
        (_: {
          sopsFile = cfg.secretsFile;
          owner = cfg.user;
          group = cfg.group;
          restartUnits = ["node-red.service"];
        });

      sops.templates."node-red-credentials.env".content = ''
        NODE_RED_CREDENTIAL_SECRET=${config.sops.placeholder.NODE_RED_CREDENTIAL_SECRET}
      '';

      # ────────────────────────────────────────────────────────────────────────
      # Wire env file to service
      # ────────────────────────────────────────────────────────────────────────
      services.nodered-service.credentialsEnvFile =
        config.sops.templates."node-red-credentials.env".path;
    };
  };
}
