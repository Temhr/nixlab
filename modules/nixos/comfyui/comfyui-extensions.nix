{ config, lib, pkgs, ... }:

let
  cfg = config.services.comfyui-p5000;
  extensionsCfg = config.services.comfyui-extensions;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.comfyui-extensions = {
      # REQUIRED: Enable ComfyUI extensions/custom nodes
      enable = lib.mkEnableOption "ComfyUI Extensions and Custom Nodes";

      # OPTIONAL: Install ComfyUI-Manager (highly recommended)
      enableManager = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install ComfyUI-Manager for easy custom node management";
      };

      # OPTIONAL: Install ControlNet models and nodes
      enableControlNet = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install ControlNet custom nodes";
      };

      # OPTIONAL: Install image processing nodes
      enableImageProcessing = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install common image processing custom nodes";
      };

      # OPTIONAL: Install video processing nodes
      enableVideoProcessing = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install video processing custom nodes (requires more dependencies)";
      };

      # OPTIONAL: Custom nodes to install from git repos
      customNodes = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the custom node";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "Git repository URL";
            };
            rev = lib.mkOption {
              type = lib.types.str;
              default = "main";
              description = "Git revision (branch, tag, or commit)";
            };
          };
        });
        default = [];
        example = [
          {
            name = "ComfyUI-Impact-Pack";
            url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
            rev = "main";
          }
        ];
        description = "List of custom nodes to install from git repositories";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when extensions are enabled
  # ============================================================================
  config = lib.mkIf (cfg.enable && extensionsCfg.enable) {

    # ----------------------------------------------------------------------------
    # CUSTOM NODES INSTALLER - One-shot service to install extensions
    # ----------------------------------------------------------------------------
    systemd.services.comfyui-extensions-setup = {
      description = "Install ComfyUI Extensions and Custom Nodes";
      wantedBy = [ "comfyui.service" ];
      before = [ "comfyui.service" ];
      after = [ "comfyui-pytorch-setup.service" ];
      requires = [ "comfyui-pytorch-setup.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "comfyui";
        Group = "comfyui";
        RemainAfterExit = true;
        WorkingDirectory = cfg.dataDir;
      };

      path = [ pkgs.git pkgs.python311 ];

      script = ''
        set -e
        CUSTOM_NODES_DIR="${cfg.dataDir}/custom_nodes"
        VENV_DIR="${cfg.dataDir}/venv"

        # Create custom_nodes directory if it doesn't exist
        mkdir -p "$CUSTOM_NODES_DIR"

        # Install GitPython for ComfyUI-Manager
        echo "Installing GitPython for Manager..."
        $VENV_DIR/bin/pip install --no-cache-dir GitPython || echo "Warning: Failed to install GitPython"

        echo "Installing ComfyUI extensions..."

        ${lib.optionalString extensionsCfg.enableManager ''
          # Install ComfyUI-Manager
          echo "Installing ComfyUI-Manager..."
          if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI-Manager" ]; then
            ${pkgs.git}/bin/git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$CUSTOM_NODES_DIR/ComfyUI-Manager"
          else
            echo "ComfyUI-Manager already installed, updating..."
            cd "$CUSTOM_NODES_DIR/ComfyUI-Manager"
            ${pkgs.git}/bin/git pull || echo "Warning: Failed to update ComfyUI-Manager"
          fi

          # Install Manager dependencies
          if [ -f "$CUSTOM_NODES_DIR/ComfyUI-Manager/requirements.txt" ]; then
            $VENV_DIR/bin/pip install -r "$CUSTOM_NODES_DIR/ComfyUI-Manager/requirements.txt" || echo "Warning: Some Manager dependencies failed to install"
          fi
        ''}

        ${lib.optionalString extensionsCfg.enableControlNet ''
          # Install ControlNet Preprocessors
          echo "Installing ControlNet Preprocessors..."
          if [ ! -d "$CUSTOM_NODES_DIR/comfyui_controlnet_aux" ]; then
            ${pkgs.git}/bin/git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git "$CUSTOM_NODES_DIR/comfyui_controlnet_aux"
          else
            echo "ControlNet Preprocessors already installed"
          fi

          # Install dependencies
          if [ -f "$CUSTOM_NODES_DIR/comfyui_controlnet_aux/requirements.txt" ]; then
            $VENV_DIR/bin/pip install -r "$CUSTOM_NODES_DIR/comfyui_controlnet_aux/requirements.txt" || echo "Warning: Some ControlNet dependencies failed to install"
          fi
        ''}

        ${lib.optionalString extensionsCfg.enableImageProcessing ''
          # Install ComfyUI-Image-Filters (common image processing nodes)
          echo "Installing Image Processing nodes..."
          if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts" ]; then
            ${pkgs.git}/bin/git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git "$CUSTOM_NODES_DIR/ComfyUI-Custom-Scripts"
          else
            echo "Image Processing nodes already installed"
          fi

          # Install WAS Node Suite (popular utilities)
          if [ ! -d "$CUSTOM_NODES_DIR/was-node-suite-comfyui" ]; then
            ${pkgs.git}/bin/git clone https://github.com/WASasquatch/was-node-suite-comfyui.git "$CUSTOM_NODES_DIR/was-node-suite-comfyui"
          else
            echo "WAS Node Suite already installed"
          fi

          # Install dependencies
          for req in "$CUSTOM_NODES_DIR"/*/requirements.txt; do
            if [ -f "$req" ]; then
              echo "Installing dependencies from $req"
              $VENV_DIR/bin/pip install -r "$req" || echo "Warning: Some dependencies from $req failed to install"
            fi
          done
        ''}

        ${lib.optionalString extensionsCfg.enableVideoProcessing ''
          # Install ComfyUI-VideoHelperSuite
          echo "Installing Video Processing nodes..."
          if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite" ]; then
            ${pkgs.git}/bin/git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite"
          else
            echo "Video Processing nodes already installed"
          fi

          # Install dependencies
          if [ -f "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite/requirements.txt" ]; then
            $VENV_DIR/bin/pip install -r "$CUSTOM_NODES_DIR/ComfyUI-VideoHelperSuite/requirements.txt" || echo "Warning: Some video dependencies failed to install"
          fi
        ''}

        # Install user-specified custom nodes
        ${lib.concatMapStringsSep "\n" (node: ''
          echo "Installing custom node: ${node.name}..."
          if [ ! -d "$CUSTOM_NODES_DIR/${node.name}" ]; then
            ${pkgs.git}/bin/git clone ${node.url} "$CUSTOM_NODES_DIR/${node.name}"
            cd "$CUSTOM_NODES_DIR/${node.name}"
            ${pkgs.git}/bin/git checkout ${node.rev} || echo "Warning: Failed to checkout ${node.rev}"
          else
            echo "Custom node ${node.name} already installed"
          fi

          # Install requirements if they exist
          if [ -f "$CUSTOM_NODES_DIR/${node.name}/requirements.txt" ]; then
            echo "Installing dependencies for ${node.name}..."
            $VENV_DIR/bin/pip install -r "$CUSTOM_NODES_DIR/${node.name}/requirements.txt" || echo "Warning: Some dependencies for ${node.name} failed to install"
          fi

          # Run install script if it exists
          if [ -f "$CUSTOM_NODES_DIR/${node.name}/install.py" ]; then
            echo "Running install script for ${node.name}..."
            cd "$CUSTOM_NODES_DIR/${node.name}"
            $VENV_DIR/bin/python install.py || echo "Warning: Install script for ${node.name} failed"
          fi
        '') extensionsCfg.customNodes}

        echo "ComfyUI extensions installation complete!"
        echo "Installed extensions will be available in: $CUSTOM_NODES_DIR"
      '';
    };

    # ----------------------------------------------------------------------------
    # UPDATE SERVICE CONFIG - Point ComfyUI to custom nodes directory
    # ----------------------------------------------------------------------------
    systemd.services.comfyui = {
      environment = {
        # Tell ComfyUI where to find custom nodes
        COMFYUI_CUSTOM_NODES_PATH = "${cfg.dataDir}/custom_nodes";
      };

      # Ensure extensions are installed before starting
      after = [ "comfyui-extensions-setup.service" ];
      requires = [ "comfyui-extensions-setup.service" ];
    };

    # ----------------------------------------------------------------------------
    # CREATE SYMLINK - Link custom nodes to ComfyUI directory
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/custom_nodes 0770 comfyui comfyui -"
      # Create symlink from ComfyUI installation to custom nodes directory
      "L+ ${pkgs.comfyui}/share/comfyui/custom_nodes - - - - ${cfg.dataDir}/custom_nodes"
    ];
  };
}

/*
================================================================================
COMFYUI EXTENSIONS MODULE - CUSTOM NODES AND ADDONS
================================================================================

This module installs popular ComfyUI extensions and custom nodes.

USAGE
-----
Import this module alongside your comfyui-p5000 module:

In your configuration.nix:
```nix
imports = [
  ./modules/nixos/comfyui-p5000.nix
  ./modules/nixos/comfyui-extensions.nix
];

services.comfyui-p5000 = {
  enable = true;
};

services.comfyui-extensions = {
  enable = true;

  # Recommended: Install ComfyUI-Manager (enabled by default)
  enableManager = true;

  # Optional: Enable ControlNet support
  enableControlNet = true;

  # Optional: Enable common image processing nodes
  enableImageProcessing = true;

  # Optional: Enable video processing nodes
  enableVideoProcessing = false;

  # Optional: Install custom nodes from git repos
  customNodes = [
    {
      name = "ComfyUI-Impact-Pack";
      url = "https://github.com/ltdrdata/ComfyUI-Impact-Pack";
      rev = "main";
    }
    {
      name = "ComfyUI-AnimateDiff-Evolved";
      url = "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved";
      rev = "main";
    }
  ];
};
```

INCLUDED EXTENSIONS
-------------------
ComfyUI-Manager (enableManager = true):
  - Package manager for ComfyUI
  - Easily install/update custom nodes through the web UI
  - Browse and install models
  - Essential tool for managing ComfyUI ecosystem

ControlNet (enableControlNet = true):
  - ControlNet preprocessors
  - Depth, pose, canny edge detection
  - Enables precise control over image generation

Image Processing (enableImageProcessing = true):
  - ComfyUI-Custom-Scripts: Quality of life improvements
  - WAS Node Suite: Popular utilities and image manipulation nodes

Video Processing (enableVideoProcessing = false):
  - ComfyUI-VideoHelperSuite: Video frame extraction and creation
  - AnimateDiff support preparation

COMFYUI-MANAGER
---------------
The Manager is the most important extension. Once installed, you can:
- Install custom nodes directly from the ComfyUI web interface
- Browse the custom node registry
- Update all nodes with one click
- See which nodes are missing dependencies

Access Manager in ComfyUI:
1. Click "Manager" button in the web interface
2. Browse and install nodes
3. Update nodes
4. See installation status

CUSTOM NODES
------------
You can install any custom node from a git repository using the `customNodes`
option. The module will:
1. Clone the repository
2. Install requirements.txt if present
3. Run install.py if present
4. Keep the installation persistent across rebuilds

Popular custom nodes to consider:
- ComfyUI-Impact-Pack: Advanced detailing and segmentation
- ComfyUI-AnimateDiff-Evolved: Animation generation
- ComfyUI-Advanced-ControlNet: Enhanced ControlNet features
- ComfyUI-IPAdapter-plus: IP-Adapter support
- ComfyUI-Inspire-Pack: Collection of useful nodes

DIRECTORY STRUCTURE
-------------------
Custom nodes are installed in: /data/comfyui/custom_nodes/
Each node gets its own subdirectory

UPDATING EXTENSIONS
-------------------
To update extensions, restart the setup service:
  sudo systemctl restart comfyui-extensions-setup

Or rebuild your system (extensions update on rebuild):
  sudo nixos-rebuild switch

TROUBLESHOOTING
---------------
View extension installation logs:
  sudo journalctl -u comfyui-extensions-setup -n 100

Check custom nodes directory:
  ls -la /data/comfyui/custom_nodes/

If a custom node fails to load:
  - Check ComfyUI logs: sudo journalctl -u comfyui -f
  - Verify dependencies: Look for import errors
  - Use ComfyUI-Manager to diagnose missing dependencies

NOTES
-----
- Custom nodes are persistent across system rebuilds
- Each node's dependencies are installed in the venv
- Failed dependency installations don't block the service
- ComfyUI-Manager can install additional nodes at runtime
*/
