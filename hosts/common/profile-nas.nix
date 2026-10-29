{self, ...}: {
  flake.nixosModules.hosts--profl--nas = {...}: {
    imports = [
      self.nixosModules.hosts--autom--backup-phone-media
    ];
    services.prometheus-nixlab.maintenance.expectedMounts = ["/mirror"];
    services.nixlab-monitoring.access.interfaces = [hostMeta.ethIface];
  };
}
