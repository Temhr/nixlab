{...}: {
  flake.nixosModules.hardw--mounts--local-data = {...}: {
    fileSystems."/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
      options = ["defaults" "auto"];
    };
  };
}
