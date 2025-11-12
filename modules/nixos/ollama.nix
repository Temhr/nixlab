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

      # OPTIONAL: Auto-open firewall ports (default: false)
      # Usually you access Ollama via localhost or reverse proxy
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall ports";
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
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
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
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open Ollama port if not using reverse proxy or binding to non-localhost
      lib.optionals (cfg.domain == null && cfg.bindIP != "127.0.0.1") [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration (CPU only):
----------------------------------
services.ollama-custom = {
  enable = true;
};
# API at: http://localhost:11434


With GPU acceleration (NVIDIA):
--------------------------------
services.ollama-custom = {
  enable = true;
  acceleration = "cuda";
  models = [ "llama3.2" ];  # Pre-download models
};


Network access (for Open WebUI):
---------------------------------
services.ollama-custom = {
  enable = true;
  bindIP = "0.0.0.0";
  openFirewall = true;
  acceleration = "cuda";
  models = [ "llama3.2" "mistral" ];
};


Full configuration with domain:
--------------------------------
services.ollama-custom = {
  enable = true;
  port = 11434;
  bindIP = "127.0.0.1";
  dataDir = "/mnt/storage/ollama";  # Large storage for models
  acceleration = "cuda";

  # Pre-download models
  models = [ "llama3.2" "mistral" "codellama" ];

  # Performance tuning
  environmentVariables = {
    OLLAMA_NUM_PARALLEL = "4";      # Parallel requests
    OLLAMA_MAX_LOADED_MODELS = "2"; # Models in memory
  };

  # Nginx reverse proxy
  domain = "ollama.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
GPU ACCELERATION
================================================================================

NVIDIA GPU (CUDA):
  acceleration = "cuda";
  Requires: nvidia drivers installed
  Check: nvidia-smi

AMD GPU (ROCm):
  acceleration = "rocm";
  Requires: AMD GPU drivers

Auto-detect:
  acceleration = null;
  Ollama will auto-detect available GPU

CPU only:
  acceleration = false;
  Slower but works on any hardware


================================================================================
MANAGING MODELS
================================================================================

Pre-download models (in config):
  models = [ "llama3.2" "mistral" ];
  Downloaded on service start

Download models manually:
  ollama pull llama3.2
  ollama pull mistral
  ollama pull codellama:7b

List installed models:
  ollama list

Remove a model:
  ollama rm llama3.2

Model sizes (approximate):
  - llama3.2:1b      ~1.3GB
  - llama3.2:3b      ~2.0GB
  - llama3.2         ~4.9GB (default, 3B params)
  - mistral          ~4.1GB
  - codellama        ~3.8GB
  - llama3.1:70b     ~40GB
  - llama3.1:405b    ~231GB


================================================================================
USING OLLAMA
================================================================================

Test the API:
  curl http://localhost:11434/api/generate -d '{
    "model": "llama3.2",
    "prompt": "Why is the sky blue?"
  }'

Interactive chat:
  ollama run llama3.2

List running models:
  ollama ps

Stop a model:
  ollama stop llama3.2


================================================================================
INTEGRATIONS
================================================================================

Open WebUI (Web interface for Ollama):
  Install Open WebUI separately
  Point it to: http://localhost:11434
  Or use bindIP = "0.0.0.0" for network access

Continue.dev (VSCode extension):
  Install Continue extension
  Configure Ollama endpoint: http://localhost:11434

LangChain / LlamaIndex:
  Use Ollama's OpenAI-compatible API
  Endpoint: http://localhost:11434/v1


================================================================================
PERFORMANCE TUNING
================================================================================

Environment variables for tuning:

OLLAMA_NUM_PARALLEL:
  Number of parallel requests (default: 1)
  Set higher for multiple concurrent users
  Example: "4"

OLLAMA_MAX_LOADED_MODELS:
  Models to keep in memory (default: 1)
  Set higher if you use multiple models
  Uses more RAM
  Example: "2"

OLLAMA_MAX_QUEUE:
  Max queued requests (default: 512)
  Example: "1024"

OLLAMA_DEBUG:
  Enable debug logging
  Example: "1"


================================================================================
STORAGE REQUIREMENTS
================================================================================

Ollama stores models in dataDir (default: /var/lib/ollama)

Plan storage carefully:
  - Small models: 1-4GB each
  - Medium models: 7-13GB each
  - Large models: 40-70GB each
  - XL models: 200GB+ each

Recommended:
  - Use separate large drive for models
  - Set dataDir to mounted storage
  - Monitor disk usage


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status ollama

View logs:
  sudo journalctl -u ollama -f

Test API manually:
  curl http://localhost:11434/api/tags

GPU not detected:
  Check drivers: nvidia-smi (NVIDIA) or rocm-smi (AMD)
  Check logs: journalctl -u ollama -f

Out of memory:
  Reduce OLLAMA_MAX_LOADED_MODELS
  Use smaller models
  Add more RAM

Model download failed:
  Check internet connection
  Check disk space: df -h
  Manually download: ollama pull llama3.2

Slow responses:
  Enable GPU acceleration
  Use smaller models
  Reduce OLLAMA_NUM_PARALLEL

*/
