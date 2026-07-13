{...}: let
  mkMachineMeta = {
    cpuVendor ? "intel",
    initrdAvailableKernelModules ? [],
    initrdKernelModules ? [],
    kernelModules ? [],
    extraModulePackages ? [],
    enableRedistributableFirmware ? true,
    extraConfig ? {},
  }: {
    inherit cpuVendor initrdAvailableKernelModules initrdKernelModules kernelModules
    extraModulePackages enableRedistributableFirmware extraConfig;
  };
in {
  flake.lib.hardwareMeta = {
    m720q-nas1 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ahci" "mpt3sas" "nvme" "usbhid" "sd_mod"];
      kernelModules = ["kvm-intel"];
    };
    m720q-nas2 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ahci" "uas" "sd_mod"];
      kernelModules = ["kvm-intel"];
    };
    zb15g2-k1 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = ["kvm-intel"];
    };
    zb17g1-k3 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = ["kvm-intel"];
    };
    zb17g1-k4 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = ["kvm-intel"];
    };
    zb17g2-k5 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = ["kvm-intel"];
    };
    zb17g4-p5 = mkMachineMeta {
      cpuVendor = "intel";
      initrdAvailableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" "rtsx_pci_sdmmc"];
      kernelModules = ["kvm-intel"];
    };
  };
}
