{...}: {
  flake.nixosModules.hardw--core--nvidia = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.driver-nvidia;
  in {
    options = {
      driver-nvidia = {
        driver-branch = lib.mkOption {
          type = lib.types.enum ["none" "l470" "l535" "l580" "stable"];
          default = "none";
          description = "Select which between three options or none";
        };
      };
    };
    config = lib.mkMerge [
      # Base nvidia config, shared by "l" and "s"
      (lib.mkIf (cfg.driver-branch != "none") {
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
      # legacy 470 driver - Quadro series (e.g. K2200)
      (lib.mkIf (cfg.driver-branch == "l470") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
      })
      # legacy 535 driver - Quadro series (e.g. P5000)
      (lib.mkIf (cfg.driver-branch == "l535") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_535;
      })
      # legacy 580 driver - Quadro series (e.g. P5000)
      (lib.mkIf (cfg.driver-branch == "l580") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      })
      # stable driver
      (lib.mkIf (cfg.driver-branch == "stable") {
        hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
      })
    ];
  };
}
