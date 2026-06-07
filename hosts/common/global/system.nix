{self, ...}: {
  flake.nixosModules.hosts--c-glo--system = {...}: {
    systemd.services.home-manager-temhr.serviceConfig.Environment = [
      "XDG_RUNTIME_DIR=/run/user/1000"
    ];
  };
}
