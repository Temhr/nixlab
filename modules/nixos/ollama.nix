{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollama-webui-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.ollama-webui-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Ollama with Open WebUI";

      # OPTIONAL: Port for Ollama API (default: 11434)
      ollamaPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for Ollama API to listen on";
      };

      # OPTIONAL: Port for Open WebUI (default: 3000)
      webuiPort = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port for Open WebUI to listen on";
      };

      # OPTIONAL: IP to bind Ollama to (default: 127.0.0.1 = localhost only)
      ollamaBindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Ollama to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: IP to bind Open WebUI to (default: 127.0.0.1 = localhost only)
      webuiBindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Open WebUI to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "ollama.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Ollama models (default: /var/lib/ollama)
      ollamaDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/ollama";
        example = "/data/ollama";
        description = "Directory for Ollama models and data";
      };

      # OPTIONAL: Where to store Open WebUI data (default: /var/lib/open-webui)
      webuiDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/open-webui";
        example = "/data/open-webui";
        description = "Directory for Open WebUI data";
      };

      # OPTIONAL: Enable GPU acceleration (default: false)
      enableGPU = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GPU acceleration for Ollama (requires CUDA)";
      };

      # OPTIONAL: Models to download on first start
      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "llama2" "mistral" "codellama" ];
        description = "List of models to pull on service start";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.ollamaDataDir} 0770 ollama ollama -"
      "d ${cfg.webuiDataDir} 0770 open-webui open-webui -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system users
    # ----------------------------------------------------------------------------
    users.users.ollama = {
      isSystemUser = true;
      group = "ollama";
      home = cfg.ollamaDataDir;
      description = "Ollama service user";
    };

    users.groups.ollama = {};

    users.users.open-webui = {
      isSystemUser = true;
      group = "open-webui";
      home = cfg.webuiDataDir;
      description = "Open WebUI service user";
    };

    users.groups.open-webui = {};
    users.users.temhr.extraGroups = [ "ollama" "open-webui" ];

    # ----------------------------------------------------------------------------
    # OLLAMA SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.ollama = {
      description = "Ollama LLM Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        OLLAMA_HOST = "${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
        OLLAMA_MODELS = "${cfg.ollamaDataDir}/models";
      } // lib.optionalAttrs cfg.enableGPU {
        # Enable GPU acceleration if requested
        CUDA_VISIBLE_DEVICES = "0";
      };

      serviceConfig = {
        Type = "simple";
        User = "ollama";
        Group = "ollama";
        WorkingDirectory = cfg.ollamaDataDir;
        ExecStart = "${pkgs.ollama}/bin/ollama serve";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.ollamaDataDir ];
      } // lib.optionalAttrs cfg.enableGPU {
        # GPU device access
        DeviceAllow = [ "/dev/nvidia0" "/dev/nvidiactl" "/dev/nvidia-uvm" ];
      };

      # Download requested models after service starts
      postStart = lib.optionalString (cfg.models != [ ]) ''
        sleep 5  # Wait for Ollama to be ready
        ${lib.concatMapStringsSep "\n" (model: ''
          ${pkgs.ollama}/bin/ollama pull ${model} || true
        '') cfg.models}
      '';
    };

    # ----------------------------------------------------------------------------
    # OPEN WEBUI SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.open-webui = {
      description = "Open WebUI for Ollama";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "ollama.service" ];
      requires = [ "ollama.service" ];

      environment = {
        OLLAMA_BASE_URL = "http://${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
        WEBUI_AUTH = "True";
        DATA_DIR = cfg.webuiDataDir;
        HOST = cfg.webuiBindIP;
        PORT = toString cfg.webuiPort;
      };

      serviceConfig = {
        Type = "simple";
        User = "open-webui";
        Group = "open-webui";
        WorkingDirectory = cfg.webuiDataDir;
        ExecStart = "${pkgs.open-webui}/bin/open-webui serve";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.webuiDataDir ];
      };
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        forceSSL = cfg.enableSSL;
        enableACME = cfg.enableSSL;

        locations."/" = {
          proxyPass = "http://${cfg.webuiBindIP}:${toString cfg.webuiPort}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
          '';
        };

        # Proxy for Ollama API (accessible at /api)
        locations."/api" = {
          proxyPass = "http://${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open WebUI and Ollama ports if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.webuiPort cfg.ollamaPort ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    # ----------------------------------------------------------------------------
    # GPU SUPPORT - Add CUDA packages if GPU is enabled
    # ----------------------------------------------------------------------------
    environment.systemPackages = lib.optionals cfg.enableGPU [
      pkgs.cudatoolkit
    ];
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.ollama-webui-custom = {
  enable = true;
};
# Ollama API: http://your-ip:11434
# Open WebUI: http://your-ip:3000


With models pre-downloaded:
----------------------------
services.ollama-webui-custom = {
  enable = true;
  models = [ "llama2" "mistral" "codellama" ];
};


Full configuration with domain and GPU:
----------------------------------------
services.ollama-webui-custom = {
  enable = true;
  ollamaPort = 11434;
  webuiPort = 3000;
  ollamaBindIP = "0.0.0.0";
  webuiBindIP = "0.0.0.0";
  ollamaDataDir = "/data/ollama";
  webuiDataDir = "/data/open-webui";

  # GPU acceleration
  enableGPU = true;

  # Pre-download models
  models = [ "llama2" "mistral" "codellama" ];

  # Nginx reverse proxy
  domain = "ollama.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
USAGE
================================================================================

First-time setup:
1. Access Open WebUI at http://your-ip:3000 (or your domain)
2. Create an admin account (first user becomes admin)
3. Download models through the UI or configure in models list

Download models manually:
  ollama pull llama2
  ollama pull mistral
  ollama pull codellama

List downloaded models:
  ollama list

Run a model directly:
  ollama run llama2


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status ollama
  sudo systemctl status open-webui

View logs:
  sudo journalctl -u ollama -f
  sudo journalctl -u open-webui -f

Test Ollama API:
  curl http://localhost:11434/api/tags

Restart services:
  sudo systemctl restart ollama
  sudo systemctl restart open-webui

GPU issues:
  nvidia-smi  # Check GPU status
  # Ensure CUDA is properly installed
  # Check journalctl logs for CUDA errors

Model storage location:
  /var/lib/ollama/models (or your custom ollamaDataDir)

WebUI data location:
  /var/lib/open-webui (or your custom webuiDataDir)

*/
