{...}: {
  flake.nixosModules.hardw--c-optional--driver-nvidia = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.driver-nvidia;
  in {
    options = {
      driver-nvidia = {
        quadro = lib.mkOption {
          type = lib.types.enum ["none" "k" "p"];
          default = "none";
          description = "Select which between three options or none";
        };
      };
    };
    config = lib.mkMerge [
      # Base nvidia config, shared by "k" and "p"
      (lib.mkIf (cfg.quadro != "none") {
        hardware.graphics = {
          enable = true;
        };
        services.xserver.videoDrivers = ["nvidia"];
        boot.blacklistedKernelModules = ["nouveau"];
        hardware.nvidia = {
          modesetting.enable = true;
          powerManagement = {
            enable = true;
            finegrained = false;
          };
          open = false;
          nvidiaSettings = true;
          prime = {
            offload.enable = false;
            sync.enable = true;
            nvidiaBusId = "PCI:1:0:0";
            intelBusId = "PCI:0:2:0";
          };
        };
        environment.systemPackages = with pkgs; [
          vulkan-tools
          stable.cudaPackages.cudatoolkit
        ];

        boot.kernelParams = ["nvidia-drm.modeset=1" "nvidia-drm.fbdev=1"];
        boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];
        environment.sessionVariables = {
          NIXOS_OZONE_WL = "1";
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          WLR_NO_HARDWARE_CURSORS = "1"; # fixes invisible/broken cursor on NVIDIA
          LIBVA_DRIVER_NAME = "nvidia";
        };
      })
      # Quadro K series (e.g. K2200) — legacy 470 driver
      (lib.mkIf (cfg.quadro == "k") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
      })
      # Quadro P series (e.g. P5000) — stable driver
      (lib.mkIf (cfg.quadro == "p") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
      })
    ];
  };
}
