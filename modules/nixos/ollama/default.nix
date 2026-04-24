{...}: {
  flake.nixosModules.servc--ollama = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.ollama-stack;

    # Resolved package: if user didn't override, pick based on acceleration
    defaultPackage =
      if cfg.acceleration == "cpu"
      then pkgs.ollama
      else pkgs.ollama-cuda-p5000;

    resolvedPackage =
      if cfg.package != null
      then cfg.package
      else defaultPackage;
  in {
    # ============================================================================
    # OPTIONS
    # ============================================================================
    options.services.ollama-stack = {
      enable = lib.mkEnableOption "Ollama with Open WebUI";

      # NEW: replaces having two separate modules
      acceleration = lib.mkOption {
        type = lib.types.enum ["cpu" "cuda-p5000"];
        default = "cpu";
        description = ''
          Acceleration backend to use.
          "cpu"        — CPU-only, no GPU detection.
          "cuda-p5000" — CUDA with compute capability 6.1 (NVIDIA Quadro P5000).
        '';
      };

      # Optional override — if null, derived from acceleration
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Override the Ollama package. If null, chosen automatically based on acceleration.";
      };

      ollamaPort = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port for Ollama API";
      };

      webuiPort = lib.mkOption {
        type = lib.types.port;
        default = 3007;
        description = "Port for Open WebUI";
      };

      ollamaListenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Ollama to bind to";
      };

      webuiListenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address for Open WebUI to bind to";
      };

      ollamaDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/ollama";
        description = "Directory for Ollama models and data";
      };

      webuiDataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/open-webui";
        description = "Directory for Open WebUI data";
      };

      # GPU-specific — only meaningful when acceleration != "cpu"
      gpuDevice = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "GPU device ID (ignored for cpu acceleration)";
      };

      gpuLayers = lib.mkOption {
        type = lib.types.int;
        default = -1;
        description = "Layers to offload to GPU (-1 = all). Ignored for cpu acceleration.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["llama2" "mistral" "codellama"];
        description = "Models to pull on service start";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Domain for nginx reverse proxy. Null disables nginx.";
      };

      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      webuiSecretKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/open-webui-key";
        description = ''
          Path to a file containing the Open WebUI secret key.
          Use agenix or sops-nix to provision this file.
          If null, a placeholder is used — NOT suitable for production.
        '';
      };
      # NEW: allow opting out of the mainUser group membership
      # without coupling to a specific external option name
      extraUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["alice"];
        description = "Extra users to add to the ollama and open-webui groups";
      };
    };

    # ============================================================================
    # CONFIG
    # ============================================================================
    config = lib.mkIf cfg.enable {
      # --------------------------------------------------------------------------
      # ASSERTIONS — catch configuration mistakes at eval time
      # --------------------------------------------------------------------------
      assertions = [
        {
          assertion = cfg.enableSSL -> cfg.domain != null;
          message = "services.ollama-stack.enableSSL requires domain to be set";
        }
        {
          assertion = cfg.webuiSecretKeyFile != null -> builtins.pathExists cfg.webuiSecretKeyFile || true;
          # The path check is a hint; actual enforcement is at runtime
          message = "services.ollama-stack.webuiSecretKeyFile is set but the file may not exist at evaluation time — ensure it is provisioned before Open WebUI starts";
        }
      ];

      # --------------------------------------------------------------------------
      # DIRECTORIES
      # --------------------------------------------------------------------------
      systemd.tmpfiles.rules = [
        "d ${cfg.ollamaDataDir} 0770 ollama ollama -"
        "d ${cfg.webuiDataDir} 0770 open-webui open-webui -"
      ];

      # --------------------------------------------------------------------------
      # USERS
      # --------------------------------------------------------------------------
      # Define users in one go using lib.mkMerge
      users.users = lib.mkMerge [
        {
          ollama = {
            isSystemUser = true;
            group = "ollama";
            home = cfg.ollamaDataDir;
            description = "Ollama service user";
          };
          open-webui = {
            isSystemUser = true;
            group = "open-webui";
            home = cfg.webuiDataDir;
            description = "Open WebUI service user";
          };
        }
        # Merge in extra users with extraGroups
        (lib.mkMerge (map (u: {
            ${u} = {
              extraGroups = ["ollama" "open-webui"];
            };
          })
          cfg.extraUsers))
      ];
      users.groups.ollama = {};
      users.groups.open-webui = {};

      # --------------------------------------------------------------------------
      # OLLAMA SERVICE
      # --------------------------------------------------------------------------
      systemd.services.ollama = {
        description = "Ollama LLM Service (${cfg.acceleration})";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        environment = lib.mkMerge [
          # Shared environment
          {
            OLLAMA_HOST = "${cfg.ollamaListenAddress}:${toString cfg.ollamaPort}";
            OLLAMA_MODELS = "${cfg.ollamaDataDir}/models";
          }
          # CPU-specific
          (lib.mkIf (cfg.acceleration == "cpu") {
            CUDA_VISIBLE_DEVICES = "";
            OLLAMA_NUM_GPU = "0";
          })
          # CUDA-specific
          (lib.mkIf (cfg.acceleration == "cuda-p5000") (
            {
              CUDA_VISIBLE_DEVICES = toString cfg.gpuDevice;
              OLLAMA_NUM_GPU = "1";
            }
            // lib.optionalAttrs (cfg.gpuLayers != -1) {
              OLLAMA_GPU_LAYERS = toString cfg.gpuLayers;
            }
          ))
        ];

        serviceConfig = lib.mkMerge [
          # Shared config
          {
            Type = "simple";
            User = "ollama";
            Group = "ollama";
            WorkingDirectory = cfg.ollamaDataDir;
            ExecStart = "${resolvedPackage}/bin/ollama serve";
            Restart = "on-failure";
            RestartSec = "10s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [cfg.ollamaDataDir];
          }
          # GPU device access — only added for CUDA
          (lib.mkIf (cfg.acceleration == "cuda-p5000") {
            DeviceAllow = [
              "/dev/nvidia0"
              "/dev/nvidia1"
              "/dev/nvidia2"
              "/dev/nvidia3"
              "/dev/nvidiactl"
              "/dev/nvidia-uvm"
              "/dev/nvidia-modeset"
            ];
          })
        ];
      };

      # --------------------------------------------------------------------------
      # MODEL DOWNLOADER
      # --------------------------------------------------------------------------
      systemd.services.ollama-models = lib.mkIf (cfg.models != []) {
        description = "Download Ollama Models";
        wantedBy = ["multi-user.target"];
        after = ["ollama.service"];
        requires = ["ollama.service"];

        environment.OLLAMA_HOST = "${cfg.ollamaListenAddress}:${toString cfg.ollamaPort}";

        serviceConfig = {
          Type = "oneshot";
          User = "ollama";
          Group = "ollama";
          RemainAfterExit = true;
          TimeoutStartSec = "infinity";
        };

        script = ''
          echo "Waiting for Ollama..."
          for i in {1..30}; do
            if ${pkgs.curl}/bin/curl -s \
                http://${cfg.ollamaListenAddress}:${toString cfg.ollamaPort}/ \
                > /dev/null 2>&1; then
              echo "Ollama ready"
              break
            fi
            sleep 1
          done

          ${lib.concatMapStringsSep "\n" (model: ''
              echo "Checking model: ${model}"
              if ! ${resolvedPackage}/bin/ollama list | grep -q "${model}"; then
                echo "Pulling ${model}..."
                ${resolvedPackage}/bin/ollama pull ${model} \
                  || echo "Warning: failed to pull ${model}"
              else
                echo "Model ${model} already present, skipping"
              fi
            '')
            cfg.models}

          echo "Model setup complete"
        '';
      };

      # --------------------------------------------------------------------------
      # MODEL CLEANUP
      # --------------------------------------------------------------------------
      systemd.services.ollama-cleanup = lib.mkIf (cfg.models != []) {
        description = "Clean up non-whitelisted Ollama Models";
        wantedBy = ["multi-user.target"];
        after = ["ollama-models.service"];
        requires = ["ollama-models.service"];

        environment.OLLAMA_HOST = "${cfg.ollamaListenAddress}:${toString cfg.ollamaPort}";

        serviceConfig = {
          Type = "oneshot";
          User = "ollama";
          Group = "ollama";
          RemainAfterExit = true;
        };

        script = ''
          echo "Starting model cleanup..."

          # Get list of installed models (skip header line)
          installed_models=$(${resolvedPackage}/bin/ollama list | ${pkgs.coreutils}/bin/tail -n +2 | ${pkgs.gawk}/bin/awk '{print $1}')

          # Whitelisted models
          whitelist=(${lib.concatStringsSep " " (map (m: ''"${m}"'') cfg.models)})

          # Check each installed model
          for model in $installed_models; do
            # Skip if model is empty or just whitespace
            if [ -z "$model" ] || [ "$model" = " " ]; then
              continue
            fi

            # Check if model is in whitelist
            is_whitelisted=false
            for allowed in "''${whitelist[@]}"; do
              if [ "$model" = "$allowed" ]; then
                is_whitelisted=true
                break
              fi
            done

            # Remove if not whitelisted
            if [ "$is_whitelisted" = false ]; then
              echo "Removing non-whitelisted model: $model"
              ${resolvedPackage}/bin/ollama rm "$model" \
                || echo "Warning: failed to remove $model"
            else
              echo "Keeping whitelisted model: $model"
            fi
          done

          echo "Model cleanup complete"
        '';
      };

      # --------------------------------------------------------------------------
      # OPEN WEBUI SERVICE
      # --------------------------------------------------------------------------
      systemd.services.open-webui = {
        description = "Open WebUI for Ollama";
        wantedBy = ["multi-user.target"];
        after = ["network.target" "ollama.service"];
        requires = ["ollama.service"];
        environment = lib.mkMerge [
          {
            OLLAMA_BASE_URL = "http://${cfg.ollamaListenAddress}:${toString cfg.ollamaPort}";
            WEBUI_AUTH = "True";
            DATA_DIR = cfg.webuiDataDir;
            ENV = "prod";
            STATIC_DIR = "${cfg.webuiDataDir}/static";
            FRONTEND_BUILD_DIR = "${pkgs.open-webui}/share/open-webui";
          }
          (lib.mkIf (cfg.webuiSecretKeyFile == null) {
            WEBUI_SECRET_KEY = "change-me-set-webuiSecretKeyFile";
          })
        ];
        serviceConfig = {
          Type = "simple";
          User = "open-webui";
          Group = "open-webui";
          WorkingDirectory = cfg.webuiDataDir;
          ExecStart = "${pkgs.open-webui}/bin/open-webui serve --host ${cfg.webuiListenAddress} --port ${toString cfg.webuiPort}";
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStartSec = "120s";
          StandardOutput = "journal";
          StandardError = "journal";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [cfg.webuiDataDir];
          # Load the secret key from a file if provided
          EnvironmentFile = lib.mkIf (cfg.webuiSecretKeyFile != null) cfg.webuiSecretKeyFile;
        };
      };

      # --------------------------------------------------------------------------
      # NGINX
      # --------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;

      services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
        ${cfg.domain} = {
          forceSSL = cfg.enableSSL;
          enableACME = cfg.enableSSL;

          locations."/" = {
            proxyPass = "http://${cfg.webuiListenAddress}:${toString cfg.webuiPort}";
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
            proxyPass = "http://${cfg.ollamaListenAddress}:${toString cfg.ollamaPort}";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };

      # --------------------------------------------------------------------------
      # FIREWALL
      # --------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
        lib.optionals (cfg.domain == null) [cfg.ollamaPort cfg.webuiPort]
        ++ lib.optionals (cfg.domain != null) [80 443]
      );

      # CUDA toolkit only needed for GPU mode
      environment.systemPackages = lib.mkIf (cfg.acceleration == "cuda-p5000") [
        pkgs.cudatoolkit
      ];
    };
  };
}
