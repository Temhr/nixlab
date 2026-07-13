{self, ...}: {
  flake.nixosModules.hardw--zb17g4-p5 = {...}: {
    imports = [
      (self.lib.mkHardwareProfile "zb17g4-p5") # explicit — no config lookup, no ambiguity
      self.nixosModules.hardw--profl--workstation-nvidia
    ];
    # Choose between these choices: "none" "l470" "l535" "l580" "stable"
    driver-nvidia.driver-branch = "l580";
  };
}
