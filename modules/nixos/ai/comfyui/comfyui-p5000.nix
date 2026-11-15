{self, ...}: {
  flake.nixosModules.servc--comfyui-p5000 = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.comfyui-p5000;
    # Python used for the venv. If ComfyUI's requirements need a newer Python,
    # switch to pkgs.python312 (PyTorch cu126 wheels exist for it too).
    py = pkgs.python311;

    # Last PyTorch release with a prebuilt Pascal (sm_61) wheel is 2.14 (cu126).
    torchSpec = "torch==2.14.0 torchvision==0.29.0 torchaudio";
    torchIndex = "https://download.pytorch.org/whl/cu126";
  in {
    imports = [
      self.nixosModules.systm--ports-comfyui
    ];
    # ============================================================================
    # OPTIONS - Define what can be configured
    # ============================================================================
    options = {
      services.comfyui-p5000 = {
        # REQUIRED: Enable the service
        enable = lib.mkEnableOption "ComfyUI (GPU-accelerated for P5000)";

        # OPTIONAL: Port for ComfyUI (default: 8188)
        port = lib.mkOption {
          type = lib.types.port;
          default = 8188;
          description = "Port for ComfyUI to listen on";
        };

        # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "IP address for ComfyUI to bind to (use 0.0.0.0 for all interfaces)";
        };

        # OPTIONAL: Where to store ComfyUI data (default: /var/lib/comfyui)
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/comfyui";
          example = "/data/comfyui";
          description = "Directory for ComfyUI models, outputs, and data";
        };

        # OPTIONAL: GPU device to use
        gpuDevice = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "GPU device ID to use (0 for first GPU)";
        };

        # OPTIONAL: Auto-open firewall port (default: true)
        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open firewall port";
        };

        # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
        domain = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "comfyui.example.com";
          description = "Domain name for nginx reverse proxy (optional)";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "comfyui";
          description = "User to run Comfyui as";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "comfyui";
          description = "Group to run Comfyui as";
        };

        # OPTIONAL: allow opting out of the mainUser group membership
        # without coupling to a specific external option name
        extraUsers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["alice"];
          description = "Extra users to add to the groups";
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
        "d ${cfg.dataDir} 0770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/models 0770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/output 0770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/input 0770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/temp 0770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/user 0770 ${cfg.user} ${cfg.group} -"
      ];

      # ----------------------------------------------------------------------------
      # USER SETUP - Create dedicated system user
      # ----------------------------------------------------------------------------
      users.users = lib.mkMerge (
        [
          {
            ${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
              home = cfg.dataDir;
              description = "ComfyUI service user";
            };
          }
        ]
        ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = [cfg.group];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );

      users.groups.${cfg.group} = {};

      # ----------------------------------------------------------------------------
      # PERMISSIONS - fix ownership every boot, after dataDir is actually mounted
      # ----------------------------------------------------------------------------
      systemd.services.comfyui-permissions = nixlabLib.mkDataDirPermissionsService {
        inherit pkgs;
        dataDir = cfg.dataDir;
        user = cfg.user;
        group = cfg.group;
        requiredBy = [
          "comfyui-patch.service"
          "comfyui-pytorch-setup.service"
          "comfyui.service"
        ];
      };

      # ----------------------------------------------------------------------------
      # COMFYUI SOURCE SYNC - copy the Nix-store source into a writable dir
      #
      # Re-copies whenever the pkgs.comfyui store path changes, so bumping the
      # version in the overlay actually takes effect.
      # ----------------------------------------------------------------------------
      systemd.services.comfyui-patch = {
        description = "Sync ComfyUI source into the data dir";
        wantedBy = ["comfyui.service"];
        before = ["comfyui.service"];
        after = ["comfyui-permissions.service"];

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          RemainAfterExit = true;
        };

        script = ''
          SRC="${pkgs.comfyui}/share/comfyui"
          DST="${cfg.dataDir}/comfyui"
          SENTINEL="${cfg.dataDir}/.comfyui-src"

          if [ ! -d "$DST" ] || ! grep -qxF "$SRC" "$SENTINEL" 2>/dev/null; then
            echo "Syncing ComfyUI from $SRC"
            rm -rf "$DST"
            cp -r "$SRC" "$DST"
            chmod -R u+w "$DST"
            echo "$SRC" > "$SENTINEL"
          fi

          # custom_nodes lives in the data dir so it survives upgrades
          mkdir -p "${cfg.dataDir}/custom_nodes"
          rm -rf "$DST/custom_nodes"
          ln -sfn "${cfg.dataDir}/custom_nodes" "$DST/custom_nodes"
        '';
      };

      # ----------------------------------------------------------------------------
      # PYTHON ENV - PyTorch (cu126, includes sm_61) + ComfyUI's own requirements
      #
      # NOTE: this needs network access at setup time (PyTorch index + PyPI).
      # A sentinel records torch spec + python + ComfyUI store path; the venv is
      # rebuilt whenever any of them changes.
      # ----------------------------------------------------------------------------
      systemd.services.comfyui-pytorch-setup = {
        description = "Install PyTorch cu126 (Pascal) and ComfyUI requirements";
        wantedBy = ["comfyui.service"];
        before = ["comfyui.service"];
        after = [
          "comfyui-permissions.service"
          "comfyui-patch.service"
          "network-online.target"
        ];
        wants = ["network-online.target"];
        requires = ["comfyui-patch.service"];

        environment = {
          LD_LIBRARY_PATH = lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.glib
            pkgs.zlib
          ];
          HOME = cfg.dataDir;
        };

        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          RemainAfterExit = true;
          WorkingDirectory = cfg.dataDir;
          TimeoutStartSec = "infinity";
        };

        path = [py pkgs.coreutils pkgs.gnugrep];

        script = ''
          set -e
          VENV="${cfg.dataDir}/venv"
          SENTINEL="$VENV/.setup-version"
          WANT="${torchSpec} ${torchIndex} ${py} ${pkgs.comfyui}"

          if [ -x "$VENV/bin/python" ] && [ "$(cat "$SENTINEL" 2>/dev/null)" = "$WANT" ]; then
            echo "Python env up to date — skipping"
            exit 0
          fi

          echo "(Re)creating venv..."
          rm -rf "$VENV"
          ${py}/bin/python -m venv "$VENV"
          "$VENV/bin/pip" install --upgrade pip

          echo "Installing PyTorch (cu126)..."
          "$VENV/bin/pip" install ${torchSpec} --index-url ${torchIndex}

          # Freeze the torch family so later installs can't replace it
          "$VENV/bin/pip" freeze | grep -iE '^(torch|torchvision|torchaudio)==' > "$VENV/constraints.txt"
          cat "$VENV/constraints.txt"

          # ComfyUI's requirements, minus the torch lines we installed above
          REQ="$(mktemp)"
          grep -viE '^(torch|torchvision|torchaudio)([<>=! ]|$)' \
            "${cfg.dataDir}/comfyui/requirements.txt" > "$REQ"
          echo "Installing ComfyUI requirements..."
          "$VENV/bin/pip" install -r "$REQ" -c "$VENV/constraints.txt"
          rm -f "$REQ"

          echo "$WANT" > "$SENTINEL"

          "$VENV/bin/python" - <<'PY'
          import torch
          print("torch", torch.__version__, "| cuda available:", torch.cuda.is_available())
          print("arch list:", torch.cuda.get_arch_list())  # must contain sm_61
          PY
        '';
      };

      # ----------------------------------------------------------------------------
      # COMFYUI SERVICE - GPU-ACCELERATED
      # ----------------------------------------------------------------------------
      systemd.services.comfyui = {
        description = "ComfyUI Stable Diffusion Service (GPU - P5000)";
        wantedBy = ["multi-user.target"];
        after = ["network.target" "comfyui-permissions.service" "comfyui-pytorch-setup.service" "comfyui-patch.service"];
        requires = ["comfyui-pytorch-setup.service" "comfyui-patch.service"];

        unitConfig = {
          ConditionPathExists = "${cfg.dataDir}/venv/bin/python";
        };

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/user";
          ExecStart = "${cfg.dataDir}/venv/bin/python ${cfg.dataDir}/comfyui/main.py --listen ${cfg.listenAddress} --port ${toString cfg.port} --base-directory ${cfg.dataDir} --temp-directory ${cfg.dataDir}/temp --input-directory ${cfg.dataDir}/input --output-directory ${cfg.dataDir}/output --extra-model-paths-config ${cfg.dataDir}/extra_model_paths.yaml";
          Restart = "on-failure";
          RestartSec = "10s";

          Environment = [
            "CUDA_VISIBLE_DEVICES=${toString cfg.gpuDevice}"
            "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512"
            "COMFYUI_EXTRA_MODEL_PATHS=${cfg.dataDir}/extra_model_paths.yaml"
            "VIRTUAL_ENV=${cfg.dataDir}/venv"
            "COMFYUI_USER_DIRECTORY=${cfg.dataDir}/user"
            "PATH=${cfg.dataDir}/venv/bin:${pkgs.git}/bin:${pkgs.uv}/bin:${pkgs.coreutils}/bin:/run/current-system/sw/bin"
            "PYTHONPATH="
            "LD_LIBRARY_PATH=/run/opengl-driver/lib:${lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.glib
              pkgs.zlib
              pkgs.linuxPackages.nvidia_x11
              pkgs.libGL
              pkgs.libGLU
              pkgs.libX11
              pkgs.libXext
            ]}"
          ];

          DeviceAllow = [
            "/dev/nvidia0"
            "/dev/nvidia1"
            "/dev/nvidia2"
            "/dev/nvidia3"
            "/dev/nvidiactl"
            "/dev/nvidia-uvm"
            "/dev/nvidia-modeset"
          ];

          # GPU services need relaxed sandboxing.
          # PrivateDevices = false is required — true blocks /dev/nvidia*.
          # PrivateTmp = false is required — CUDA uses /tmp for IPC (error 304 otherwise).
          NoNewPrivileges = true;
          PrivateDevices = false;
          PrivateTmp = false;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [cfg.dataDir];
        };
      };

      # ----------------------------------------------------------------------------
      # NGINX REVERSE PROXY - Only configured if domain is set
      # ----------------------------------------------------------------------------
      services.nginx.enable = lib.mkIf (cfg.domain != null) true;
      services.nginx.virtualHosts = nixlabLib.mkNginxVirtualHost {
        inherit (cfg) domain listenAddress port enableSSL;
        extraConfig = ''
          proxy_buffering off;
          client_max_body_size 100M;
        '';
      };

      # ----------------------------------------------------------------------------
      # FIREWALL - Open necessary port if requested
      # ----------------------------------------------------------------------------
      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.openFirewall
        (nixlabLib.mkFirewallPorts {
          inherit (cfg) domain listenAddress;
          servicePort = cfg.port;
        });
    };
  };
}
/*
================================================================================
COMFYUI P5000 MODULE - GPU-ACCELERATED STABLE DIFFUSION
================================================================================

This module provides ComfyUI with CUDA support for the NVIDIA Quadro P5000 GPU.

PyTorch comes from PyTorch's cu126 wheel index into a venv (cu126 is the last
build that still includes Pascal / sm_61; 2.14 is the last release with it).
The ComfyUI source version is set in overlays/_comfyui-p5000.nix.

USAGE
-----
Minimal configuration:
```nix
services.comfyui-p5000 = {
  enable = true;
};
```

Access:
- ComfyUI Web Interface: http://localhost:8188

Full configuration with all options:
```nix
services.comfyui-p5000 = {
  enable = true;

  # Network configuration
  port = 8188;
  listenAddress = "0.0.0.0";  # Listen on all interfaces

  # Data directory (models, outputs, inputs)
  dataDir = "/data/comfyui";

  # GPU configuration
  gpuDevice = 0;      # First GPU

  # Reverse proxy with SSL
  domain = "comfyui.example.com";
  enableSSL = true;
  openFirewall = true;
};
```

DIRECTORY STRUCTURE
-------------------
ComfyUI expects the following directory structure:
- ${dataDir}/models/     - Stable Diffusion models, VAE, LoRA, etc.
- ${dataDir}/output/     - Generated images
- ${dataDir}/input/      - Input images for img2img
- ${dataDir}/temp/       - Temporary files

DOWNLOADING MODELS
------------------
Place your Stable Diffusion models in:
  ${dataDir}/models/checkpoints/

Example models to download:
- SD 1.5: https://huggingface.co/runwayml/stable-diffusion-v1-5
- SDXL: https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0

TECHNICAL DETAILS
-----------------
The P5000 has CUDA compute capability 6.1 (Pascal architecture) with 16GB VRAM.
This is sufficient for:
- SD 1.5 models with full resolution (512x512)
- SDXL models at reduced resolution or with --lowvram flag
- Multiple LoRA and ControlNet models

ComfyUI will automatically use CUDA if available. The service sets:
- CUDA_VISIBLE_DEVICES: Select which GPU to use
- PYTORCH_CUDA_ALLOC_CONF: Optimize memory allocation

TROUBLESHOOTING
---------------
Check GPU is being used:
  watch nvidia-smi

View service logs:
  sudo journalctl -u comfyui -f

Test the service is running:
  curl http://localhost:8188

Check CUDA availability in Python:
  python -c "import torch; print(torch.cuda.is_available())"

If out of memory on SDXL:
  Add --lowvram or --novram flags to ExecStart

PERFORMANCE TIPS
----------------
- P5000 has 16GB VRAM - suitable for SD 1.5 and SDXL with optimization
- Use --preview-method auto for generation previews
- Enable xformers for faster attention computation
- Use fp16 models when possible to reduce VRAM usage

CREDITS
-------
Module structure based on the ollama-p5000.nix pattern.
ComfyUI: https://github.com/comfyanonymous/ComfyUI
*/

