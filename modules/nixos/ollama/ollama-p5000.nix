{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollama-p5000;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.ollama-p5000 = {
      enable = lib.mkEnableOption "Ollama with Open WebUI (GPU-accelerated for P5000)";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ollama-cuda-p5000;
        defaultText = lib.literalExpression "pkgs.ollama-cuda-p5000";
        description = "The Ollama package to use (built with P5000 compute capability 6.1 support)";
      };

      ollamaPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for Ollama API to listen on";
      };

      webuiPort = lib.mkOption {
        type = lib.types.port;
        default = 3007;
        description = "Port for Open WebUI to listen on";
      };

      ollamaBindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Ollama to bind to (use 0.0.0.0 for all interfaces)";
      };

      webuiBindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Open WebUI to bind to (use 0.0.0.0 for all interfaces)";
      };

      ollamaDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/ollama";
        example = "/data/ollama";
        description = "Directory for Ollama models and data";
      };

      webuiDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/open-webui";
        example = "/data/open-webui";
        description = "Directory for Open WebUI data";
      };

      gpuDevice = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "GPU device ID to use (0 for first GPU)";
      };

      gpuLayers = lib.mkOption {
        type = lib.types.int;
        default = -1;
        description = "Number of layers to offload to GPU (-1 = all layers)";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "llama2" "mistral" "codellama" ];
        description = "List of models to pull on service start";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "ollama.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

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

    # Allow current user to access ollama and open-webui data
    users.users.temhr.extraGroups = [ "open-webui" "ollama" ];

    # ----------------------------------------------------------------------------
    # OLLAMA SERVICE - CPU-ONLY MODE
    # ----------------------------------------------------------------------------
    systemd.services.ollama = {
      description = "Ollama LLM Service (GPU - P5000)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        OLLAMA_HOST = "${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
        OLLAMA_MODELS = "${cfg.ollamaDataDir}/models";
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
        ExecStart = "${cfg.package}/bin/ollama serve";
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
        echo "Waiting for Ollama service..."
        for i in {1..30}; do
          if ${pkgs.curl}/bin/curl -s http://${cfg.ollamaBindIP}:${toString cfg.ollamaPort}/ > /dev/null 2>&1; then
            echo "Ollama is ready"
            break
          fi
          sleep 1
        done

        ${lib.concatMapStringsSep "\n" (model: ''
          echo "Checking model: ${model}"
          if ! ${cfg.package}/bin/ollama list | grep -q "^${model}"; then
            echo "Downloading model: ${model} (this may take a while...)"
            ${cfg.package}/bin/ollama pull ${model} || echo "Warning: Failed to download ${model}"
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
        OLLAMA_HOST = "http://${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
        WEBUI_AUTH = "true";
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

    # Include CUDA toolkit in system packages
    environment.systemPackages = [
      pkgs.cudatoolkit
    ];
  };
}

/*
================================================================================
OLLAMA P5000 MODULE - GPU-ACCELERATED INFERENCE
================================================================================

This module provides Ollama with CUDA support for the NVIDIA Quadro P5000 GPU.

IMPORTANT: This module requires a companion overlay to create the
`pkgs.ollama-cuda-p5000` package with compute capability 6.1 support.

Add to your overlays/default.nix:
```nix
modifications = final: prev: {
  ollama-cuda-p5000 = (prev.ollama-cuda.override {
    cudaArches = [ "sm_61" "sm_75" "sm_80" "sm_86" "sm_89" "sm_90" ];
  }).overrideAttrs (old: {
    pname = "ollama-cuda-p5000";
    name = "ollama-cuda-p5000-${old.version}";
  });
};
```

USAGE
-----
Minimal configuration:
```nix
services.ollama-p5000 = {
  enable = true;
};
```

Access:
- Ollama API: http://localhost:11434
- Open WebUI: http://localhost:3007

Full configuration with all options:
```nix
services.ollama-p5000 = {
  enable = true;

  # Network configuration
  ollamaPort = 11434;
  webuiPort = 3007;
  ollamaBindIP = "0.0.0.0";  # Listen on all interfaces
  webuiBindIP = "0.0.0.0";

  # Data directories
  ollamaDataDir = "/data/ollama";
  webuiDataDir = "/data/open-webui";

  # GPU configuration
  gpuDevice = 0;      # First GPU
  gpuLayers = -1;     # Offload all layers to GPU (-1 = auto)

  # Pre-download models
  models = [ "llama2" "mistral" "codellama" ];

  # Reverse proxy with SSL
  domain = "ollama.example.com";
  enableSSL = true;
  openFirewall = true;
};
```

TECHNICAL DETAILS
-----------------
The P5000 has CUDA compute capability 6.1 (Pascal architecture).

The default NixOS ollama-cuda package only supports compute capabilities
75, 80, 86, 89, 90, 100, 120 (Turing and newer), which causes the error:
"CUDA error: no kernel image is available for execution on the device"

The solution is to override the `cudaArches` parameter to include "sm_61".
The overlay creates a custom package that compiles CUDA kernels for multiple
architectures including the P5000.

TROUBLESHOOTING
---------------
Check GPU is being used:
  watch nvidia-smi

View service logs:
  sudo journalctl -u ollama -f

Test the API:
  curl http://localhost:11434/api/generate -d '{
    "model":"llama2",
    "prompt":"Hello",
    "stream":false
  }'

Verify correct package:
  nix eval .#nixosConfigurations.YOUR_HOST.config.services.ollama-p5000.package.name
  # Should output: "ollama-cuda-p5000-0.x.x"

Check CUDA architectures in build log:
  nix log $(nix-store -qd $(which ollama)) | grep "Using CUDA arch"
  # Should include: 61

CREDITS
-------
Solution based on the cudaArches override pattern documented in the
NixOS ollama package.nix (line 18).

*/
