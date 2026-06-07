{self, ...}: {
  flake.nixosModules.hosts--c-glo--bluetooth = {...}: {
    hardware.bluetooth.enable = true; # enables support for Bluetooth
    hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  };
}
