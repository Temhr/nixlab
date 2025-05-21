# Disko configuration for partitioning and formatting
{
  disko.devices = {
    disk = {
      ssd = {
        type = "disk";
        # Use more reliable device identifiers
        device = "/dev/sdb"; # Replace with your actual disk ID
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
        device = "/dev/sda"; # Replace with your actual disk ID
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
