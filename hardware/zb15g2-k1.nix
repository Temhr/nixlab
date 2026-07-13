{self, ...}: {
  flake.nixosModules.hardw--zb15g2-k1 = {...}: {
    imports = [
      (self.lib.mkHardwareProfile "zb15g2-k1") # explicit — no config lookup, no ambiguity
      self.nixosModules.hardw--profl--workstation-nvidia
    ];
  };
}
