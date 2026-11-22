{self, ...}: {
  flake.nixosModules.hosts--profl--nas = {hostMeta ? {}, ...}: {
    imports = [
      self.nixosModules.hosts--autom--backup-phone-media
    ];
    services.observability-prometheus.maintenance.expectedMounts = ["/mirror"];
    services.observability.access.interfaces = [hostMeta.ethIface];
  };
}
