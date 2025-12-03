{ config, lib, pkgs, ... }:

let
  cfg = config.services.comfyui-p5000;
in
{
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
      bindIP = lib.mkOption {
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
      "d ${cfg.dataDir} 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/output 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/input 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/temp 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/user 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/database 0770 comfyui comfyui -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user
    # ----------------------------------------------------------------------------
    users.users.comfyui = {
      isSystemUser = true;
      group = "comfyui";
      home = cfg.dataDir;
      description = "ComfyUI service user";
    };
    users.groups.comfyui = {};

    # Allow current user to access comfyui data
    users.users.temhr.extraGroups = [ "comfyui" ];

    # ----------------------------------------------------------------------------
    # COMFYUI PATCH - Fix PyTorch 2.2 compatibility
    # ----------------------------------------------------------------------------
    systemd.services.comfyui-patch = {
      description = "Patch ComfyUI for PyTorch 2.2 compatibility";
      wantedBy = [ "comfyui.service" ];
      before = [ "comfyui.service" ];
      after = [ "comfyui-pytorch-setup.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "comfyui";
        Group = "comfyui";
        RemainAfterExit = true;
      };

      script = ''
        # Copy ComfyUI to a writable location if not already done
        COMFYUI_SRC="${pkgs.comfyui}/share/comfyui"
        COMFYUI_PATCHED="${cfg.dataDir}/comfyui"

        if [ ! -d "$COMFYUI_PATCHED" ]; then
          echo "Copying ComfyUI to writable location..."
          cp -r "$COMFYUI_SRC" "$COMFYUI_PATCHED"
          chmod -R u+w "$COMFYUI_PATCHED"
        fi

        # Create symlink to custom_nodes directory
        if [ ! -L "$COMFYUI_PATCHED/custom_nodes" ]; then
          echo "Removing default custom_nodes and creating symlink..."
          rm -rf "$COMFYUI_PATCHED/custom_nodes"
          ln -sf "${cfg.dataDir}/custom_nodes" "$COMFYUI_PATCHED/custom_nodes"
        fi

        # Patch ops.py for PyTorch 2.2 compatibility
        OPS_FILE="$COMFYUI_PATCHED/comfy/ops.py"

        if grep -q "torch.compiler.is_compiling()" "$OPS_FILE"; then
          echo "Patching ops.py for PyTorch 2.2 compatibility..."

          # Replace torch.compiler.is_compiling() with a compatibility check
          sed -i 's/if torch.compiler.is_compiling():/if hasattr(torch.compiler, "is_compiling") and torch.compiler.is_compiling():/' "$OPS_FILE"

          echo "Patch applied successfully"
        else
          echo "ops.py already patched or doesn't need patching"
        fi

        echo "ComfyUI patched and custom_nodes symlink created"
      '';
    };

    # ----------------------------------------------------------------------------
    # PYTORCH INSTALLER - One-shot service to install PyTorch 2.2 with CUDA support
    # ----------------------------------------------------------------------------
    systemd.services.comfyui-pytorch-setup = {
      description = "Install PyTorch 2.2 for ComfyUI (P5000 support)";
      wantedBy = [ "comfyui.service" ];
      before = [ "comfyui.service" ];

      environment = {
        LD_LIBRARY_PATH = lib.makeLibraryPath [
          pkgs.stdenv.cc.cc.lib
          pkgs.glib
          pkgs.zlib
        ];
      };

      serviceConfig = {
        Type = "oneshot";
        User = "comfyui";
        Group = "comfyui";
        RemainAfterExit = true;
        WorkingDirectory = cfg.dataDir;
      };

      path = [ pkgs.python311 ];

      script = ''
        set -e
        VENV_DIR="${cfg.dataDir}/venv"

        # Create venv if it doesn't exist
        if [ ! -d "$VENV_DIR" ]; then
          echo "Creating Python virtual environment..."
          ${pkgs.python311}/bin/python -m venv "$VENV_DIR"
        fi

        # Force reinstall if numpy 2.x is detected
        NUMPY_VERSION=$($VENV_DIR/bin/python -c "import numpy; print(numpy.__version__)" 2>/dev/null || echo "0")
        if [[ "$NUMPY_VERSION" == 2.* ]]; then
          echo "NumPy 2.x detected, forcing reinstall with numpy<2..."
          $VENV_DIR/bin/pip uninstall -y numpy
        fi

        # Check if all dependencies are installed
        if $VENV_DIR/bin/python -c "import torch, torchvision, torchaudio, yaml, PIL, aiohttp, torchsde, av, pydantic, alembic; import numpy; assert numpy.__version__.startswith('1.'); from comfyui_frontend_package import __version__; from comfyui_workflow_templates import __version__ as wt; from comfyui_embedded_docs import __version__ as ed" 2>/dev/null; then
          echo "All dependencies already installed with correct versions"
          exit 0
        fi

        echo "Installing PyTorch 2.2.2 with CUDA 11.8 support (sm_61 for P5000)..."
        $VENV_DIR/bin/pip install --no-cache-dir \
          torch==2.2.2 \
          torchvision==0.17.2 \
          torchaudio==2.2.2 \
          --index-url https://download.pytorch.org/whl/cu118

        echo "Installing ComfyUI dependencies..."
        $VENV_DIR/bin/pip install --no-cache-dir \
          "numpy<2" \
          pillow \
          safetensors \
          aiohttp \
          pyyaml \
          tqdm \
          psutil \
          scipy \
          einops \
          opencv-python \
          matplotlib \
          transformers \
          accelerate \
          sentencepiece \
          kornia \
          torchsde \
          spandrel \
          soundfile \
          av \
          pydantic \
          pydantic-settings \
          alembic \
          comfyui-frontend-package \
          comfyui-workflow-templates \
          comfyui-embedded-docs \
          || echo "Warning: Failed to install some dependencies"

        echo "PyTorch setup complete!"
        echo "Testing CUDA availability..."
        $VENV_DIR/bin/python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')" || echo "Warning: CUDA test failed"
      '';
    };

    # ----------------------------------------------------------------------------
    # COMFYUI SERVICE - GPU-ACCELERATED
    # ----------------------------------------------------------------------------
    systemd.services.comfyui = {
      description = "ComfyUI Stable Diffusion Service (GPU - P5000)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "comfyui-pytorch-setup.service" "comfyui-patch.service" ];
      requires = [ "comfyui-pytorch-setup.service" "comfyui-patch.service" ];
      # Wait for setup to complete
      unitConfig = {
        ConditionPathExists = "${cfg.dataDir}/venv/bin/python";
      };

      serviceConfig = {
        Type = "simple";
        User = "comfyui";
        Group = "comfyui";
        WorkingDirectory = cfg.dataDir;
        # Ensure user directory exists before starting
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/user";
        # Use patched ComfyUI from writable location
        ExecStart = "${cfg.dataDir}/venv/bin/python ${cfg.dataDir}/comfyui/main.py --listen ${cfg.bindIP} --port ${toString cfg.port} --user-directory ${cfg.dataDir}/user --temp-directory ${cfg.dataDir}/temp --input-directory ${cfg.dataDir}/input --output-directory ${cfg.dataDir}/output --extra-model-paths-config ${cfg.dataDir}/extra_model_paths.yaml";
        Restart = "on-failure";
        RestartSec = "10s";

        # Environment variables
        Environment = [
          "CUDA_VISIBLE_DEVICES=${toString cfg.gpuDevice}"
          "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512"
          "COMFYUI_EXTRA_MODEL_PATHS=${cfg.dataDir}/extra_model_paths.yaml"
          "VIRTUAL_ENV=${cfg.dataDir}/venv"
          # Tell ComfyUI to use our data directory for user data
          "COMFYUI_USER_DIRECTORY=${cfg.dataDir}/user"
          # Add git to PATH for ComfyUI-Manager
          "PATH=${pkgs.git}/bin:${pkgs.coreutils}/bin"
          "LD_LIBRARY_PATH=${lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.glib
            pkgs.zlib
            pkgs.cudatoolkit
            pkgs.linuxPackages.nvidia_x11
            pkgs.libGL
            pkgs.libGLU
            pkgs.xorg.libX11
            pkgs.xorg.libXext
          ]}"
          "COMFYUI_DB_PATH=${cfg.dataDir}/database/comfyui.db"
        ];

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

        # Security hardening - relaxed for GPU access
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];

        # Allow access to GPU and driver
        PrivateDevices = false;
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
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_buffering off;
            client_max_body_size 100M;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary port if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optionals (cfg.domain == null) [ cfg.port ]
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    # Include CUDA toolkit in system packages
    environment.systemPackages = [
      pkgs.cudatoolkit
      pkgs.comfyui
    ];
  };
}

/*
================================================================================
COMFYUI P5000 MODULE - GPU-ACCELERATED STABLE DIFFUSION
================================================================================

This module provides ComfyUI with CUDA support for the NVIDIA Quadro P5000 GPU.

IMPORTANT: ComfyUI needs PyTorch built with CUDA support. Ensure your nixpkgs
has CUDA support enabled.

Add to your configuration.nix:
```nix
nixpkgs.config = {
  allowUnfree = true;
  cudaSupport = true;
};
```

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
  bindIP = "0.0.0.0";  # Listen on all interfaces

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
