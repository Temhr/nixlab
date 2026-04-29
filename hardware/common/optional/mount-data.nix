{...}: {
  flake.nixosModules.hardw--c-optional--mount-data = {...}: {
    fileSystems."/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
      options = ["defaults" "auto"];
    };
  };
}
