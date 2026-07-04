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

      # ────────────────────────────────────────────────────────────────────────
      # Build env file from secrets
      # ────────────────────────────────────────────────────────────────────────
      systemd.services.node-red-secrets = {
        description = "Write Node-RED credentials env file";
        wantedBy = ["node-red.service"];
        before = ["node-red.service"];
        after = ["sops-nix.service"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };

        script = ''
          echo "NODE_RED_CREDENTIAL_SECRET=$(cat ${config.sops.secrets.NODE_RED_CREDENTIAL_SECRET.path})" \
            > /run/node-red-credentials.env
          chown ${cfg.user}:${cfg.group} /run/node-red-credentials.env
          chmod 660 /run/node-red-credentials.env
        '';
      };

      # ────────────────────────────────────────────────────────────────────────
      # Wire env file to service
      # ────────────────────────────────────────────────────────────────────────
      services.nodered-service.credentialsEnvFile = "/run/node-red-credentials.env";
    };
  };
}
