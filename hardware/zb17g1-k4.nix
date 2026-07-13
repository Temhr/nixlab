{self, ...}: {
  flake.nixosModules.hardw--zb17g1-k4 = {...}: {
    imports = [
      (self.lib.mkHardwareProfile "zb17g1-k4") # explicit — no config lookup, no ambiguity
      self.nixosModules.hardw--profl--workstation-nvidia
    ];
  };
}
