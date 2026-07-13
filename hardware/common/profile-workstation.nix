{self, ...}: {
  flake.nixosModules.hardw--profl--workstation-nvidia = {lib, ...}: {
    imports = [
      self.nixosModules.hardw--core--nvidia
      self.nixosModules.hardw--mounts--local-data
      self.nixosModules.hardw--mounts--mirror-peer
    ];
    driver-nvidia.driver-branch = lib.mkDefault "l470"; # fleet default
    mirrorPeers = lib.mkDefault ["nixnas1" "nixnas2"]; # shared across all 5 workstations
  };
}
