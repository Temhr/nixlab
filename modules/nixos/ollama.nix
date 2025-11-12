{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollama-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.ollama-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Ollama LLM service";

      # OPTIONAL: Port to listen on (default: 11434)
      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for Ollama API to listen on";
      };

      # OPTIONAL: IP to bind to (default: 0.0.0.0 for all interfaces)
      # Use "0.0.0.0" for access from other devices (e.g., for Open WebUI)
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "IP address to bind to (127.0.0.1 = localhost only)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "ollama.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Ollama models (default: /var/lib/ollama)
      # Models can be very large (7GB+ each), consider using large storage
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/ollama";
        example = "/mnt/storage/ollama";
        description = "Directory for Ollama models and data";
      };

      # OPTIONAL: Enable GPU acceleration (default: true)
      # Requires NVIDIA GPU and drivers
      acceleration = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "cuda" "rocm" false ]);
        default = null;
        example = "cuda";
        description = "GPU acceleration type (cuda for NVIDIA, rocm for AMD, null for auto-detect)";
      };

      # OPTIONAL: List of models to pre-download (default: [])
      # Models are downloaded on first service start
      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [ "llama3.2" "mistral" "codellama" ];
        description = "List of models to download automatically";
      };

      # OPTIONAL: Environment variables for Ollama
      environmentVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = { OLLAMA_NUM_PARALLEL = "4"; OLLAMA_MAX_LOADED_MODELS = "2"; };
        description = "Additional environment variables for Ollama";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      # Usually you access Ollama via localhost or reverse proxy
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # ============================================================================
      # OPEN WEBUI OPTIONS
      # ============================================================================

      webui = {
        # Enable Open WebUI web interface
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Open WebUI web interface for Ollama";
        };

        # Port for Open WebUI (default: 3006)
        port = lib.mkOption {
          type = lib.types.port;
          default = 3006;
          description = "Port for Open WebUI to listen on";
        };

        # Domain for Open WebUI nginx reverse proxy
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "chat.example.com";
          description = "Domain name for Open WebUI nginx reverse proxy (optional)";
        };

        # Enable SSL for Open WebUI
        enableSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable HTTPS with Let's Encrypt for Open WebUI (requires domain)";
        };

        # Open firewall for Open WebUI
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall port for Open WebUI";
        };

        # Additional environment variables for Open WebUI
        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = { WEBUI_AUTH = "false"; };
          description = "Additional environment variables for Open WebUI";
        };
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # OLLAMA SERVICE - Configure the built-in NixOS Ollama module
    # ----------------------------------------------------------------------------
    services.ollama = {
      enable = true;

      # Network configuration
      host = cfg.bindIP;
      port = cfg.port;

      # Storage location for models
      home = cfg.dataDir;

      # GPU acceleration
      acceleration = cfg.acceleration;

      # Models to pre-download
      # Note: This downloads on service start, can take time for large models
      loadModels = cfg.models;

      # Additional environment variables
      environmentVariables = cfg.environmentVariables;
    };

    # ----------------------------------------------------------------------------
    # OPEN WEBUI - Configure if enabled
    # ----------------------------------------------------------------------------
    services.open-webui = lib.mkIf cfg.webui.enable {
      enable = true;
      port = cfg.webui.port;

      # Automatically point to Ollama instance
      environment = {
        OLLAMA_BASE_URL = "http://${cfg.bindIP}:${toString cfg.port}";
      } // cfg.webui.environment;
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Ollama
    # ----------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null || cfg.webui.domain != null) true;

    services.nginx.virtualHosts = lib.mkMerge [
      # Ollama reverse proxy
      (lib.mkIf (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              # Increase timeout for long-running LLM requests
              proxy_read_timeout 300s;
              proxy_connect_timeout 75s;

              # Allow streaming responses
              proxy_buffering off;
            '';
          };
        };
      })

      # Open WebUI reverse proxy
      (lib.mkIf (cfg.webui.enable && cfg.webui.domain != null) {
        ${cfg.webui.domain} = {
          forceSSL = cfg.webui.enableSSL;
          enableACME = cfg.webui.enableSSL;

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.webui.port}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              # WebSocket support for real-time updates
              proxy_http_version 1.1;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "upgrade";

              # Increase timeout for long-running requests
              proxy_read_timeout 300s;
              proxy_connect_timeout 75s;
            '';
          };
        };
      })
    ];

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkMerge [
      # Ollama firewall rules
      (lib.mkIf cfg.openFirewall (
        # Open Ollama port if not using reverse proxy or binding to non-localhost
        lib.optionals (cfg.domain == null && cfg.bindIP != "127.0.0.1") [ cfg.port ]
        # Open HTTP/HTTPS if using reverse proxy
        ++ lib.optionals (cfg.domain != null) [ 80 443 ]
      ))

      # Open WebUI firewall rules
      (lib.mkIf (cfg.webui.enable && cfg.webui.openFirewall) (
        # Open WebUI port if not using reverse proxy
        lib.optionals (cfg.webui.domain == null) [ cfg.webui.port ]
        # Open HTTP/HTTPS if using reverse proxy
        ++ lib.optionals (cfg.webui.domain != null) [ 80 443 ]
      ))
    ];
  };
}

/*
================================================================================
USAGE EXAMPLES
================================================================================

Minimal configuration (CPU only, no WebUI):
--------------------------------------------
services.ollama-custom = {
  enable = true;
};
# API at: http://localhost:11434


With Open WebUI (local access only):
-------------------------------------
services.ollama-custom = {
  enable = true;
  acceleration = "cuda";
  models = [ "llama3.2" "mistral" ];

  webui = {
    enable = true;
    # Access at: http://localhost:3006
  };
};


With Open WebUI (network access):
----------------------------------
services.ollama-custom = {
  enable = true;
  bindIP = "0.0.0.0";
  openFirewall = true;
  acceleration = "cuda";
  models = [ "llama3.2" "mistral" ];

  webui = {
    enable = true;
    port = 3006;
    openFirewall = true;
  };
};
# Ollama API: http://YOUR-IP:11434
# Open WebUI: http://YOUR-IP:3006


Full configuration with domains and SSL:
-----------------------------------------
services.ollama-custom = {
  enable = true;
  port = 11434;
  bindIP = "127.0.0.1";
  dataDir = "/mnt/storage/ollama";
  acceleration = "cuda";
  models = [ "llama3.2" "mistral" "codellama" ];

  # Performance tuning
  environmentVariables = {
    OLLAMA_NUM_PARALLEL = "4";
    OLLAMA_MAX_LOADED_MODELS = "2";
  };

  # Ollama API reverse proxy
  domain = "ollama.example.com";
  enableSSL = true;
  openFirewall = true;

  # Open WebUI configuration
  webui = {
    enable = true;
    port = 3006;
    domain = "chat.example.com";
    enableSSL = true;
    openFirewall = true;

    # Optional: Disable authentication
    environment = {
      # WEBUI_AUTH = "false";  # Uncomment to disable login
    };
  };
};
# Ollama API: https://ollama.example.com
# Open WebUI: https://chat.example.com


Custom WebUI port with authentication disabled:
------------------------------------------------
services.ollama-custom = {
  enable = true;
  acceleration = "cuda";
  models = [ "llama3.2" ];

  webui = {
    enable = true;
    port = 3000;  # Custom port
    openFirewall = true;
    environment = {
      WEBUI_AUTH = "false";  # No login required
    };
  };
};
# Access at: http://localhost:3000


================================================================================
OPEN WEBUI FEATURES
================================================================================

Authentication:
  - First user becomes admin
  - Set WEBUI_AUTH = "false" to disable login
  - Supports OAuth/OIDC integration

Features:
  - Multiple chat sessions
  - Model switching (dropdown)
  - Document uploads (RAG)
  - Image generation support
  - Voice input
  - Chat history & export
  - Prompt templates
  - User management
  - Dark/light themes

Accessing from other devices:
  1. Set webui.openFirewall = true
  2. Find your IP: ip addr show
  3. Access from browser: http://YOUR-IP:3006


================================================================================
TROUBLESHOOTING
================================================================================

Open WebUI can't connect to Ollama:
  - Check Ollama is running: systemctl status ollama
  - Check bindIP allows connection (use "0.0.0.0" for network access)
  - Check firewall: systemctl status firewall
  - Test Ollama API: curl http://localhost:11434/api/tags

Open WebUI not accessible:
  - Check service: systemctl status open-webui
  - Check port is open: ss -tlnp | grep 3006
  - Check firewall: systemctl status firewall
  - View logs: journalctl -u open-webui -f

Models not showing in WebUI:
  - Wait for model download to complete
  - Check Ollama logs: journalctl -u ollama -f
  - Manually pull: ollama pull llama3.2
  - Refresh WebUI browser page

Performance issues:
  - Enable GPU acceleration
  - Use smaller models
  - Tune environment variables (OLLAMA_NUM_PARALLEL, etc)
  - Check GPU usage: nvidia-smi (NVIDIA) or rocm-smi (AMD)

*/
