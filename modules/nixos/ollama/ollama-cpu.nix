{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollama-cpu;
in {
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.ollama-cpu = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Ollama (CPU-only)";

      # OPTIONAL: Port for Ollama API (default: 11434)
      ollamaPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for Ollama API to listen on";
      };

      # OPTIONAL: IP to bind Ollama to (default: 127.0.0.1 = localhost only)
      ollamaBindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Ollama to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Where to store Ollama models (default: /var/lib/ollama)
      ollamaDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/ollama";
        example = "/data/ollama";
        description = "Directory for Ollama models and data";
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

    # ----------------------------------------------------------------------------
    # OLLAMA SERVICE - CPU-ONLY MODE
    # ----------------------------------------------------------------------------
    systemd.services.ollama-cpu = {
      description = "Ollama LLM Service (CPU)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        OLLAMA_HOST = "${cfg.ollamaBindIP}:${toString cfg.ollamaPort}";
        OLLAMA_MODELS = "${cfg.ollamaDataDir}/models";
        # Force CPU-only mode - no GPU detection
        CUDA_VISIBLE_DEVICES = "";
        OLLAMA_NUM_GPU = "0";
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

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.ollamaPort ];
  };
}


/*
================================================================================
USAGE EXAMPLE - CPU-ONLY OLLAMA
================================================================================

Minimal configuration:
----------------------
services.ollama-cpu = {
  enable = true;
};
# Ollama API: http://your-ip:11434

Full configuration:
-------------------
services.ollama-cpu = {
  enable = true;
  ollamaPort = 11434;
  ollamaBindIP = "0.0.0.0";
  ollamaDataDir = "/data/ollama";
  # Pre-download models
  models = [ "llama2" "mistral" "codellama" ];
  openFirewall = true;
};


================================================================================
NOTES
================================================================================

This module is CPU-ONLY. It explicitly disables GPU detection to prevent
crashes with unsupported or old GPUs.

Environment variables set:
  CUDA_VISIBLE_DEVICES = ""     # No GPUs visible
  OLLAMA_NUM_GPU = "0"           # Use 0 GPUs

For GPU support, use the ollama-gpu.nix module instead.

Performance expectations:
- CPU inference is slower than GPU but perfectly functional
- Works well with sufficient RAM (16GB+ recommended)
- 7B models run fine, 13B+ models need more RAM

*/
