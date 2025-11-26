{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollama-gpu;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.ollama-gpu = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Ollama with Open WebUI (GPU-accelerated)";

      # OPTIONAL: Port for Ollama API (default: 11434)
      ollamaPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for Ollama API to listen on";
      };

      # OPTIONAL: Port for Open WebUI (default: 3007)
      webuiPort = lib.mkOption {
        type = lib.types.port;
        default = 3007;
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

      # OPTIONAL: Which GPU to use (default: 0)
      gpuDevice = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "GPU device ID to use (0 for first GPU)";
      };

      # OPTIONAL: Number of layers to offload to GPU (default: -1 = all)
      gpuLayers = lib.mkOption {
        type = lib.types.int;
        default = -1;
        description = "Number of layers to offload to GPU (-1 = all layers)";
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

    # ----------------------------------------------------------------------------
    # OLLAMA SERVICE - GPU-ACCELERATED MODE
    # ----------------------------------------------------------------------------
    systemd.services.ollama = {
      description = "Ollama LLM Service (GPU)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        OLLAMA_HOST = "${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
        OLLAMA_MODELS = "${cfg.ollamaDataDir}/models";
        # GPU configuration
        CUDA_VISIBLE_DEVICES = toString cfg.gpuDevice;
        OLLAMA_NUM_GPU = "1";
      } // lib.optionalAttrs (cfg.gpuLayers != -1) {
        OLLAMA_GPU_LAYERS = toString cfg.gpuLayers;
      };

      serviceConfig = {
        Type = "simple";
        User = "ollama";
        Group = "ollama";
        WorkingDirectory = cfg.ollamaDataDir;
        ExecStart = "${pkgs.ollama}/bin/ollama serve";
        Restart = "on-failure";
        RestartSec = "10s";

        # GPU device access
        DeviceAllow = [
          "/dev/nvidia0"
          "/dev/nvidia1"
          "/dev/nvidia2"
          "/dev/nvidia3"
          "/dev/nvidiactl"
          "/dev/nvidia-uvm"
          "/dev/nvidia-modeset"
        ];

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.ollamaDataDir ];
      };
    };

    # ----------------------------------------------------------------------------
    # MODEL DOWNLOADER - Separate one-shot service for downloading models
    # ----------------------------------------------------------------------------
    systemd.services.ollama-models = lib.mkIf (cfg.models != [ ]) {
      description = "Download Ollama Models";
      wantedBy = [ "multi-user.target" ];
      after = [ "ollama.service" ];
      requires = [ "ollama.service" ];

      environment = {
        OLLAMA_HOST = "${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
      };

      serviceConfig = {
        Type = "oneshot";
        User = "ollama";
        Group = "ollama";
        RemainAfterExit = true;
        TimeoutStartSec = "infinity";
      };

      script = ''
        # Wait for Ollama to be ready
        echo "Waiting for Ollama service..."
        for i in {1..30}; do
          if ${pkgs.curl}/bin/curl -s http://${cfg.ollamaBindIP}:${toString cfg.ollamaPort}/ > /dev/null 2>&1; then
            echo "Ollama is ready"
            break
          fi
          sleep 1
        done

        # Download each model
        ${lib.concatMapStringsSep "\n" (model: ''
          echo "Checking model: ${model}"
          if ! ${pkgs.ollama}/bin/ollama list | grep -q "^${model}"; then
            echo "Downloading model: ${model} (this may take a while...)"
            ${pkgs.ollama}/bin/ollama pull ${model} || echo "Warning: Failed to download ${model}"
          else
            echo "Model ${model} already exists, skipping"
          fi
        '') cfg.models}

        echo "Model setup complete"
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
      };

      serviceConfig = {
        Type = "simple";
        User = "open-webui";
        Group = "open-webui";
        WorkingDirectory = cfg.webuiDataDir;
        ExecStart = "${pkgs.open-webui}/bin/open-webui serve --host ${cfg.webuiBindIP} --port ${toString cfg.webuiPort}";
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
      lib.optionals (cfg.domain == null) [ cfg.ollamaPort cfg.webuiPort ]
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    # ----------------------------------------------------------------------------
    # GPU SUPPORT - Add CUDA packages
    # ----------------------------------------------------------------------------
    environment.systemPackages = [
      pkgs.cudatoolkit
    ];
  };
}

/*
================================================================================
USAGE EXAMPLE - GPU-ACCELERATED OLLAMA
================================================================================

Minimal configuration:
----------------------
services.ollama-gpu = {
  enable = true;
};
# Ollama API: http://your-ip:11434 (GPU-accelerated)
# Open WebUI: http://your-ip:3007


Full configuration:
-------------------
services.ollama-gpu = {
  enable = true;
  ollamaPort = 11434;
  webuiPort = 3006;
  ollamaBindIP = "0.0.0.0";
  webuiBindIP = "0.0.0.0";
  ollamaDataDir = "/data/ollama";
  webuiDataDir = "/data/open-webui";

  # GPU settings
  gpuDevice = 0;        # First GPU
  gpuLayers = -1;       # Offload all layers (-1 = auto/all)

  # Pre-download models
  models = [ "llama2" "mistral" "codellama" ];

  # Nginx reverse proxy
  domain = "ollama.example.com";
  enableSSL = true;
  openFirewall = true;
};


================================================================================
GPU REQUIREMENTS
================================================================================

CUDA Compute Capability:
  Minimum: 7.0 (Volta architecture and newer)
  - RTX 20xx/30xx/40xx series: ✅ Supported
  - GTX 1660/1650: ✅ Supported (compute 7.5)
  - GTX 1080/1070: ✅ Supported (compute 6.1) - May need custom build
  - GTX 900 series: ❌ Not supported (compute 5.2)

Check your GPU:
  nvidia-smi
  # Look for compute capability in detailed info

If your GPU is not supported by nixpkgs ollama, you'll need to:
1. Use the CPU-only module (ollama-cpu.nix)
2. Build Ollama from source with older CUDA arch support
3. Use the official Ollama binary outside nixpkgs


================================================================================
TROUBLESHOOTING
================================================================================

Check GPU usage:
  watch -n 1 nvidia-smi

Check Ollama logs:
  sudo journalctl -u ollama -f

Verify GPU is detected:
  sudo journalctl -u ollama | grep -i "cuda\|gpu"

If models crash:
  - GPU may be too old (compute capability < 7.0)
  - Not enough VRAM (7B models need ~6GB)
  - Try reducing layers: gpuLayers = 20;

*/
