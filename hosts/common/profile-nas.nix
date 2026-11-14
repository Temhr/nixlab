{self, ...}: {
  flake.nixosModules.hosts--profl--nas = {hostMeta ? {}, ...}: {
    imports = [
      self.nixosModules.hosts--autom--backup-phone-media
    ];
    services.prometheus-nixlab.maintenance.expectedMounts = ["/mirror"];
    services.nixlab-observability.access.interfaces = [hostMeta.ethIface];
  };
}
