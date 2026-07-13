{self, ...}: {
  flake.nixosModules.hardw--zb17g2-k5 = {...}: {
    imports = [
      (self.lib.mkHardwareProfile "zb17g2-k5") # explicit — no config lookup, no ambiguity
      self.nixosModules.hardw--profl--workstation-nvidia
    ];
  };
}
