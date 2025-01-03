{ config, lib, pkgs, ... }: {

  imports = [
    ../../cachix.nix
  ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

  # Below command lists GPU and their drivers
  # $ lspci -k | grep VGA -A3
  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement = {
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
      # of just the bare essentials.
      enable = true;
      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      finegrained = false;
    };

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu, accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    # Nvidia Quadro k4100m
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;

    prime = {
      offload.enable = false;
      sync.enable = true;
      # Make sure to use the correct Bus ID values for your system!
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };
  };
  environment.systemPackages = with pkgs; [
    cachix  #Command-line client for Nix binary cache hosting https://cachix.org
    vulkan-tools  #Khronos official Vulkan Tools and Utilities
    cudaPackages.cudatoolkit  #A wrapper substituting the deprecated runfile-based CUDA installation
  ];
}
