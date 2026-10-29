{self, ...}: {
  flake.nixosModules.hosts--profl--nas = {...}: {
    imports = [
      self.nixosModules.hosts--autom--backup-phone-media
    ];
    services.prometheus-nixlab.maintenance.expectedMounts = ["/mirror"];
  };
}
