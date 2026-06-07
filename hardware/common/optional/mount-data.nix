{...}: {
  flake.nixosModules.hardw--c-opt--mount-data = {...}: {
    fileSystems."/data" = {
      device = "/dev/disk/by-label/data";
      fsType = "ext4";
      options = ["defaults" "auto"];
    };
  };
}
