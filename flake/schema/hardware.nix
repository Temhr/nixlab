{...}: {
  flake.lib.mkMachineMeta = {
    cpuVendor ? "intel",
    initrdAvailableKernelModules ? [],
    initrdKernelModules ? [],
    kernelModules ? [],
    extraModulePackages ? [],
    enableRedistributableFirmware ? true,
    extraConfig ? {},
  }: {
    inherit
      cpuVendor
      initrdAvailableKernelModules
      initrdKernelModules
      kernelModules
      extraModulePackages
      enableRedistributableFirmware
      extraConfig
      ;
  };
}
