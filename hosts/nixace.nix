# This is your system's configuration file. Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    ./common/global
    ./common/optional
    ../cachix.nix
    ../modules/nixos

    # Import your generated (nixos-generate-config) hardware configuration
    ../hardware/zb17g4-p5.nix
  ];

  # TODO: Set your hostname
  networking.hostName = "nixace";

  services.ignoreLid = {
    enable = true;
    # Optional:
    disableSleepTargets = true;
  };

  ## Enable CUPS to print documents.
  services.printing.enable = true;

  ## Enable automatic login for the user.
  services.displayManager.autoLogin.user =  "temhr";

  ## Graphical Shells ("none" "gnome" "plasma6")
  gShells.DE = "plasma6";

  ## Development
  blender.enable = true;    #3D Creation/Animation/Publishing System
  godot.enable = true;    #Free and Open Source 2D and 3D game engine
  vscodium.enable = true; #VS Code without MS branding/telemetry/licensing

  ## Education
  anki.enable = true;  #Spaced repetition flashcard program

  ## Gaming Packages
  steam.enable = true;  #Video game digital distribution service and storefront from Valve

  ## Productivity
  #calibre.enable = true;  #Comprehensive e-book software
  libreoffice.enable = true;  #Comprehensive, professional-quality productivity suite
  logseq.enable = true;  #Privacy-first, open-source platform for knowledge management and collaboration

  ## Media Packages
  obs.enable = true;  #Free and open source software for video recording and live streaming
  spotify.enable = true;  #Play music from the Spotify music service
  vlc.enable = true;  #Cross-platform media player and streaming server

  ## Virtualizations
  #bottles.enable = true;    #Easy-to-use wineprefix manager
  #distrobox.enable = true;    #Wrapper around podman or docker to create and start containers
  incus.enable = true;   #Powerful system container and virtual machine manager
  #podman.enable = true;    #A program for managing pods, containers and container images
  quickemu.enable = true;    #Quickly create and run optimised Windows, macOS and Linux virtual machines
  #virt-manager.enable = true;    #Desktop user interface for managing virtual machines
  #wine.enable = true;    #Open Source implementation of the Windows API on top of X, OpenGL, and Unix

  ## Self-hosted apps and services
  services.ollama-p5000 = {
    enable = false;
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
    models = [ "deepseek-r1:14b" "gpt-oss:20b" "gemma3:27b-it-qat" "qwen3-coder:30b-a3b-q4_K_M" ];
    openFirewall = true;
  };

  services.comfyui-p5000 = {
    enable = true;
    # Network configuration
    port = 8188;
    bindIP = "0.0.0.0";  # Listen on all interfaces
    # Data directory (models, outputs, inputs)
    dataDir = "/data/comfyui";
    # GPU configuration
    gpuDevice = 0;      # First GPU
    openFirewall = true;
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
    enableVideoProcessing = true;
    # Optional: Install custom nodes from git repos
    customNodes = [
      /*
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
      */
    ];
  };
  services.comfyui-models = {
    enable = true;
    # Download Stable Diffusion 1.5 (good for P5000 with 16GB VRAM)
    downloadSD15 = true;
    # Download SDXL (requires more VRAM, might need --lowvram flag)
    downloadSDXL = true;
    # Download recommended VAE models
    downloadVAE = true;
    # Download upscale models
    downloadUpscalers = true;
    # Download custom models
    customModels = [
      /*
      {
        name = "my-custom-model.safetensors";
        url = "https://civitai.com/api/download/models/12345";
        type = "checkpoint";
      }
      */
    ];
  };


  services.grafana-custom = {
    enable = true;
    port = 3101;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/grafana";
    # Enable maintenance dashboard
    dashboards = {
      # System maintenance dashboard
      maintenance = {
        path = ../modules/nixos/grafana/dashboards/maintenance-checklist.json;
        folder = "maintenance";
        editable = true;
      };

      # Node exporter system overview
      system-overview = {
        path = ../modules/nixos/grafana/dashboards/system-overview.json;
        folder = "maintenance";
        editable = true;
      };
    };
  };
  services.loki-custom = {
    enable = true;
    port = 3100;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/loki";
    maintenance.enable = true;
  };
  services.prometheus-custom = {
    enable = true;
    port = 9090;
    bindIP = "0.0.0.0";
    openFirewall = true;
    dataDir = "/data/prometheus";
    # Enable maintenance monitoring
    maintenance = {
      enable = true;
      exporters = {
        systemd = true;  # Service status monitoring
        smartctl = {
          enable = true;
        };
      };
    };
  };

  # Define your Flatpak packages here
  flatpakPackages = [
    "com.usebottles.bottles"
  ];

  ## List packages installed in system profile. To search, run:
  ## $ nix search wget
  environment.systemPackages = with pkgs; [

    ## Godot Dev Tools
    gcc14  #GNU Compiler Collection, version 14.1.0 (wrapper script)
    pkg-config  #Tool that allows packages to find out information about other packages (wrapper script)
    scons  #Improved, cross-platform substitute for Make
    python3  #High-level dynamically-typed programming language

  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
