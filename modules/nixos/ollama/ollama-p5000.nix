{ config, lib, pkgs, ... }:

let
  cfg = config.services.ollama-p5000;
in
{
  options = {
    services.ollama-p5000 = {
      enable = lib.mkEnableOption "Ollama with Open WebUI (GPU-accelerated for P5000)";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ollama-cuda-p5000;  # Use the overlaid package
        defaultText = lib.literalExpression "pkgs.ollama-cuda-p5000";
        description = "The Ollama package to use (patched for P5000 compute capability 6.1)";
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

  config = lib.mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d ${cfg.ollamaDataDir} 0770 ollama ollama -"
      "d ${cfg.webuiDataDir} 0770 open-webui open-webui -"
    ];

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

    users.users.temhr.extraGroups = [ "open-webui" "ollama" ];

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

        DeviceAllow = [
          "/dev/nvidia0"
          "/dev/nvidia1"
          "/dev/nvidia2"
          "/dev/nvidia3"
          "/dev/nvidiactl"
          "/dev/nvidia-uvm"
          "/dev/nvidia-modeset"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.ollamaDataDir ];
      };
    };

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

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.webuiDataDir ];
      };
    };

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

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optionals (cfg.domain == null) [ cfg.ollamaPort cfg.webuiPort ]
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    environment.systemPackages = [
      pkgs.cudatoolkit
    ];
  };
}

/*
================================================================================
P5000-SPECIFIC OLLAMA MODULE
================================================================================

This module patches Ollama's vendored llama.cpp to support CUDA compute
capability 6.1, which is required for NVIDIA Quadro P5000 GPUs.

The patching happens in postPatch, modifying the CMakeLists.txt files before
the Go build process runs.

USAGE:
------
services.ollama-p5000 = {
  enable = true;
};

DEBUGGING:
----------
If it still doesn't work, check the build logs to see if the patch was applied:
  nix-store -qR $(which ollama) | grep ollama

Then examine the build log to verify the patch ran successfully.

*/
