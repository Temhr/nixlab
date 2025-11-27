{ config, lib, pkgs, ... }:

let
  cfg = config.services.open-webui-custom;
in {
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options.services.open-webui-custom = {
    enable = lib.mkEnableOption "Open WebUI Custom";

    # OPTIONAL: Port for Open WebUI (default: 3006)
    webuiPort = lib.mkOption {
      type = lib.types.port;
      default = 3006;
      description = "Port for Open WebUI to listen on";
    };

    # OPTIONAL: IP to bind Open WebUI to (default: 127.0.0.1 = localhost only)
    webuiBindIP = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP to bind Open WebUI to";
    };

    # OPTIONAL: Where to store Open WebUI data (default: /var/lib/open-webui)
    webuiDataDir = lib.mkOption {
      type = lib.types.path;
      default = "/data/open-webui";
      example = "/data/open-webui";
      description = "Directory for Open WebUI data";
    };

    ollamaBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:11434";
      description = "URL of an Ollama instance";
    };

    # OPTIONAL: Auto-open firewall ports (default: true)
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports";
    };

    # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Nginx domain";
    };

    # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
    enableSSL = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Let's Encrypt";
    };
  };

  # ============================================================================
  # CONFIGURATION - The actual service setup
  # ============================================================================
  config = lib.mkMerge [
    # Auto-enable Open WebUI if Ollama CPU module is enabled
    {
      services.open-webui-custom.enable =
        lib.mkDefault config.services.ollama-cpu.enable;

      # Auto-connect to Ollama CPU service if it exists
      services.open-webui-custom.ollamaBaseUrl = lib.mkIf
        (config.services.ollama-cpu.enable or false)
        (lib.mkDefault "http://${config.services.ollama-cpu.ollamaBindIP}:${toString config.services.ollama-cpu.ollamaPort}");
    }

    # Main Open WebUI configuration (only when enabled)
    (lib.mkIf cfg.enable {
      # --------------------------------------------------------------------------
      # DIRECTORY SETUP - Create necessary directories with proper permissions
      # --------------------------------------------------------------------------
      systemd.tmpfiles.rules = [
        "d ${cfg.webuiDataDir} 0770 open-webui open-webui -"
      ];

      # --------------------------------------------------------------------------
      # USER SETUP - Create dedicated system users
      # --------------------------------------------------------------------------
      users.users.open-webui = {
        isSystemUser = true;
        group = "open-webui";
        home = cfg.webuiDataDir;
        description = "Open WebUI service user";
      };
      users.groups.open-webui = {};

      users.users.temhr.extraGroups = [ "open-webui" ];

      # --------------------------------------------------------------------------
      # OPEN WEBUI SERVICE - Configure the systemd service
      # --------------------------------------------------------------------------
      systemd.services.open-webui = {
        description = "Open WebUI";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ] ++ lib.optional (config.services.ollama-cpu.enable or false) "ollama-cpu.service";
        requires = lib.optional (config.services.ollama-cpu.enable or false) "ollama-cpu.service";

        environment = {
          DATA_DIR = cfg.webuiDataDir;
          OLLAMA_BASE_URL = cfg.ollamaBaseUrl;
          WEBUI_AUTH = "true";
        };

        serviceConfig = {
          Type = "simple";
          User = "open-webui";
          Group = "open-webui";
          WorkingDirectory = cfg.webuiDataDir;

          ExecStart = "${pkgs.open-webui}/bin/open-webui serve --host ${cfg.webuiBindIP} --port ${toString cfg.webuiPort}";
          Restart = "on-failure";

          # Security hardening
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ cfg.webuiDataDir ];
        };
      };

      # --------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # --------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://${cfg.webuiBindIP}:${toString cfg.webuiPort}";
            proxyWebsockets = true;
          };

          locations."/api" = lib.mkIf (config.services.ollama-cpu.enable or false) {
            proxyPass =
              "http://${config.services.ollama-cpu.ollamaBindIP}:${toString config.services.ollama-cpu.ollamaPort}";
          };
        };
      };

      # --------------------------------------------------------------------------
      # FIREWALL - Open necessary ports if requested
      # --------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall (
          lib.optionals (cfg.domain == null)
            [ cfg.webuiPort ]
          ++ lib.optionals (cfg.domain != null)
            [ 80 443 ]
        );
    })
  ];
}


/*
================================================================================
USAGE EXAMPLE - CPU-ONLY OLLAMA
================================================================================

Auto-enable (if ollama-cpu is enabled, open-webui-custom enables automatically):
--------------------------------------------------------------------------------
services.ollama-cpu.enable = true;
# open-webui-custom will auto-enable and auto-connect!


Disable auto-enable:
--------------------
services.open-webui-custom.enable = false;


Full manual configuration:
--------------------------
services.open-webui-custom = {
  enable = true;
  webuiPort = 3006;
  webuiBindIP = "0.0.0.0";
  webuiDataDir = "/data/open-webui";

  # Nginx reverse proxy
  domain = "ollama.example.com";
  enableSSL = true;
  openFirewall = true;
};
*/
