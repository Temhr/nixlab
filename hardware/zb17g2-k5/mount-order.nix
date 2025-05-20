{ config, lib, ... }: {

  # Ensure proper mount order for impermanence
  fileSystems = {
    "/persistent".neededForBoot = true;
    "/persistent/home".neededForBoot = true;
  };

  # Enable systemd in the initrd for proper boot
  boot.initrd.systemd.enable = true;
}
