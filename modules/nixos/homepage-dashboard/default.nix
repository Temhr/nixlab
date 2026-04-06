{...}: {
  flake.nixosModules.servc--homepage-nixlab = {
    config,
    lib,
    pkgs,
    hostMeta,
    ...
  }: let
    cfg = config.services.homepage-nixlab;

    # Import configurations from their respective nix files
    servicesConfig = import ./_services.nix {inherit hostMeta;};
    widgetsConfig = import ./_widgets.nix {inherit hostMeta;};
    settingsConfig = import ./_settings.nix {inherit hostMeta;};

    # Convert each to a JSON store path (remarshal converts to YAML at preStart)
    servicesJsonFile =
      builtins.toFile "services.json" (builtins.toJSON servicesConfig);
    widgetsJsonFile =
      builtins.toFile "widgets.json" (builtins.toJSON widgetsConfig);
    settingsJsonFile =
      builtins.toFile "settings.json" (builtins.toJSON settingsConfig);
  in {
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.homepage-nixlab = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "Homepage service";

        # OPTIONAL: Port to listen on (default: 3000)
        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = "Port for Homepage to listen on";
        };

        # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
        };

        # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "home.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
        # Only works if domain is set
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt (requires domain)";
        };

        # OPTIONAL: Where to store Homepage config (default: /var/lib/homepage)
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/homepage";
          example = "/data/homepage";
          description = "Directory for Homepage configuration and data";
        };

        # OPTIONAL: Homepage package to use (default: pkgs.homepage-dashboard)
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.homepage-dashboard;
          defaultText = lib.literalExpression "pkgs.homepage-dashboard";
          description = "The Homepage package to use";
        };

        # OPTIONAL: Allowed hostnames/IPs for host validation (default: ["*"] = all)
        allowedHosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["*"];
          example = ["localhost" "127.0.0.1" "home.example.com" "192.168.1.100"];
          description = "List of allowed hostnames/IPs (use [\"*\"] to allow all)";
        };

        # OPTIONAL: Auto-open firewall ports (default: true)
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall ports for HTTP/HTTPS";
        };
      };
    };

    # ============================================================================
    # CONFIG - What happens when the service is enabled
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # ----------------------------------------------------------------------------
      # USER SETUP
      # ----------------------------------------------------------------------------
      users.users.homepage = {
        isSystemUser = true;
        group = "homepage";
        home = cfg.dataDir;
        extraGroups = ["users"];
      };

      users.groups.homepage = {};

      users.users.${config.nixlab.mainUser}.extraGroups = ["homepage"];

      # ----------------------------------------------------------------------------
      # DIRECTORY SETUP
      # ----------------------------------------------------------------------------
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0770 homepage homepage -"
      ];

      # ----------------------------------------------------------------------------
      # HOMEPAGE SERVICE
      # ----------------------------------------------------------------------------
      systemd.services.homepage = {
        description = "Homepage Dashboard";
        wantedBy = ["multi-user.target"];
        after = ["network.target" "local-fs.target"];

        environment = {
          HOMEPAGE_CONFIG_DIR = "${cfg.dataDir}/config";
          PORT = toString cfg.port;
          HOSTNAME = cfg.listenAddress;
          HOMEPAGE_ALLOWED_HOSTS = lib.concatStringsSep "," cfg.allowedHosts;
        };

        preStart = let
          servicesTmp = "/tmp/homepage-services.yaml.tmp";
          widgetsTmp = "/tmp/homepage-widgets.yaml.tmp";
          settingsTmp = "/tmp/homepage-settings.yaml.tmp";
        in ''
          [ -d "${cfg.dataDir}/config" ] || mkdir -p "${cfg.dataDir}/config"
          chown homepage:homepage ${cfg.dataDir}/config/
          chmod 0770 ${cfg.dataDir}/config/

          # services.yaml
          ${pkgs.remarshal}/bin/remarshal \
            -i ${servicesJsonFile} \
            -o ${servicesTmp} \
            -if json -of yaml
          cp -f ${servicesTmp} ${cfg.dataDir}/config/services.yaml
          chmod 664 ${cfg.dataDir}/config/services.yaml
          rm -f ${servicesTmp}

          # widgets.yaml
          ${pkgs.remarshal}/bin/remarshal \
            -i ${widgetsJsonFile} \
            -o ${widgetsTmp} \
            -if json -of yaml
          cp -f ${widgetsTmp} ${cfg.dataDir}/config/widgets.yaml
          chmod 664 ${cfg.dataDir}/config/widgets.yaml
          rm -f ${widgetsTmp}

          # settings.yaml
          ${pkgs.remarshal}/bin/remarshal \
            -i ${settingsJsonFile} \
            -o ${settingsTmp} \
            -if json -of yaml
          cp -f ${settingsTmp} ${cfg.dataDir}/config/settings.yaml
          chmod 664 ${cfg.dataDir}/config/settings.yaml
          rm -f ${settingsTmp}
        '';

        serviceConfig = {
          Type = "simple";
          User = "homepage";
          Group = "homepage";
          ExecStart = "${cfg.package}/bin/homepage";
          Restart = "on-failure";
          RestartSec = "10s";

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem =
            if lib.hasPrefix "/home/" cfg.dataDir
            then "false"
            else "strict";
          ProtectHome =
            if lib.hasPrefix "/home/" cfg.dataDir
            then false
            else true;
          ReadWritePaths = [cfg.dataDir];
        };
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY
      # ----------------------------------------------------------------------------
      services.nginx = lib.mkIf (cfg.domain != null) {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;

        virtualHosts.${cfg.domain} = {
          locations."/" = {
            proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };

          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;
        };
      };

      # ----------------------------------------------------------------------------
      # FIREWALL
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        lib.optionals (cfg.domain == null && cfg.listenAddress != "127.0.0.1") [cfg.port]
        ++ lib.optionals (cfg.domain != null) [80 443]
      );
    };
  };
}
