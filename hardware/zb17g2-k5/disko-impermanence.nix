# This file should be included in your main configuration.nix
{ config, lib, pkgs, ... }:

{
  # Basic system configuration options
  boot = {
    # Ensure initrd can find your disks
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];

    # Important: supportedFilesystems and kernelModules might be needed
    supportedFilesystems = [ "ext4" "vfat" ];

    # Bootloader configuration
    loader = {
      # Use systemd-boot for UEFI systems
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  # The most important part: Directly specify filesystem mounts
  # Let's use UUIDs which are the most reliable method
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";  # If using tmpfs for root
      options = [ "defaults" "size=2G" "mode=755" ];
    };

    "/boot" = {
      # Replace with your actual UUID from `blkid` output
      device = "/dev/disk/by-label/boot";  # EFI partition UUID
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    "/persistent" = {
      # Replace with your actual UUID
      device = "/dev/disk/by-label/root";
      fsType = "ext4";
      options = [ "noatime" ];
      neededForBoot = true;  # Important if you have a tmpfs root
    };

    "/persistent/home" = {
      # Replace with your actual UUID
      device = "/dev/disk/by-label/home";
      fsType = "ext4";
      options = [ "noatime" ];
    };
  };

  # Swap configuration (using UUID for reliability)
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }  # Replace with actual UUID
  ];

  # Disable the automatic filesystem mounts that disko might be adding
  # This ensures our explicit definitions above take precedence
  disko.enableConfig = false;  # Disable disko's automatic mounting

  # Keep disko for partitioning/formatting only
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Patriot_P220_256GB_P220NIBB24110810773";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                # Don't specify mountpoint here - use fileSystems above instead
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                # Don't specify mountpoint here - use fileSystems above instead
              };
            };
          };
        };
      };
      hdd = {
        type = "disk";
        device = "/dev/disk/by-id/ata-HGST_HTS721075A9E630_JR11006P0JL6HE";
        content = {
          type = "gpt";
          partitions = {
            home = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                # Don't specify mountpoint here - use fileSystems above instead
              };
            };
          };
        };
      };
    };
  };
}
