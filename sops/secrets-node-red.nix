{...}: {
  flake.nixosModules.nsops--node-red = {
    config,
    lib,
    ...
  }: {
    # ══════════════════════════════════════════════════════════════════════════
    # OPTIONS
    # ══════════════════════════════════════════════════════════════════════════
    options.secrets.node-red = {
      enable =
        lib.mkEnableOption "Node-RED secrets management"
        // {
          default = config.services.nodered-service.enable;
        };
    };

    # ══════════════════════════════════════════════════════════════════════════
    # CONFIG
    # ══════════════════════════════════════════════════════════════════════════
    config = lib.mkIf config.secrets.node-red.enable {
      assertions = [
        {
          assertion = config.services.nodered-service ? enable;
          message = "nsops--node-red requires servc--node-red-nixlab to also be imported";
        }
      ];

      # ────────────────────────────────────────────────────────────────────────
      # Declare secrets
      # ────────────────────────────────────────────────────────────────────────
      sops.secrets =
        lib.genAttrs
        ["NODE_RED_CREDENTIAL_SECRET"]
        (_: {sopsFile = ./node-red.yaml;});

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
