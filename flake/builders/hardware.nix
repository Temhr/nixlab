{self, ...}: let
  hardwareMeta = self.lib.hardwareMeta;
in {
  flake.lib.mkHardwareProfile = machine: let
    meta =
      hardwareMeta.${machine}
      or (throw "mkHardwareProfile: no hardwareMeta entry for machine '${machine}'");
  in
    {
      config,
      lib,
      ...
    }:
      lib.mkMerge [
        {
          fileSystems."/home" = {
            device = "/dev/disk/by-label/home";
            fsType = "ext4";
          };
          fileSystems."/" = {
            device = "/dev/disk/by-label/root";
            fsType = "ext4";
          };
          fileSystems."/boot" = {
            device = "/dev/disk/by-label/boot";
            fsType = "vfat";
            options = ["fmask=0077" "dmask=0077"];
          };
          swapDevices = [{device = "/dev/disk/by-label/swap";}];

          boot.initrd.availableKernelModules = meta.initrdAvailableKernelModules;
          boot.initrd.kernelModules = meta.initrdKernelModules;
          boot.kernelModules = meta.kernelModules;
          boot.extraModulePackages = meta.extraModulePackages;
          networking.useDHCP = lib.mkDefault true;
          hardware.enableRedistributableFirmware = lib.mkDefault meta.enableRedistributableFirmware;
        }
        (lib.mkIf (meta.cpuVendor == "intel") {
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
        (lib.mkIf (meta.cpuVendor == "amd") {
          hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        })
        meta.extraConfig
      ];
}
