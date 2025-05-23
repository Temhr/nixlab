# Disko configuration for partitioning and formatting
{
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        # Use more reliable device identifiers
        device = "/dev/disk/by-id/ata-Patriot_P220_256GB_P220NIBB24110810773"; # Replace with your actual disk ID
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00"; # EFI System Partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["fmask=0077" "dmask=0077"];
              };
              # Use simple name - disko will add the prefix
              name = "boot";
            };
            swap = {
              size = "8G"; # Adjust swap size as needed
              content = {
                type = "swap";
                resumeDevice = true;
              };
              # Use simple name - disko will add the prefix
              name = "swap";
            };
            root = {
              size = "100%"; # Use the rest of the SSD
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/persistent";
                mountOptions = ["noatime"];
              };
              # Use simple name - disko will add the prefix
              name = "root";
            };
          };
        };
      };
      hdd = {
        type = "disk";
        # Use more reliable device identifiers
        device = "/dev/disk/by-id/ata-HGST_HTS721075A9E630_JR11006P0JL6HE"; # Replace with your actual disk ID
        content = {
          type = "gpt";
          partitions = {
            home = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/persistent/home";
                mountOptions = ["noatime"];
              };
              # Use simple name - disko will add the prefix
              name = "home";
            };
          };
        };
      };
    };
  };
}
