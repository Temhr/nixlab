{self, ...}: {
  flake.nixosModules.hosts--profl--nas = {hostMeta ? {}, ...}: {
    imports = [
      self.nixosModules.hosts--autom--backup-phone-media
    ];

    services.nixlab-monitoring = {
      openFirewall = false;
      access.interfaces = [hostMeta.ethIface];
      # access.expose defaults to ["grafana" "ntfy"]. Add "prometheus" here if you still want its UI from the LAN.
    };
  };
}
