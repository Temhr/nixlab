{self, ...}: {
  flake.nixosModules.hosts--core--system = {...}: {
    systemd.services.home-manager-temhr.serviceConfig.Environment = [
      "XDG_RUNTIME_DIR=/run/user/1000"
    ];

    ## Enable CUPS to print documents.
    services.printing.enable = true;
  };
}
