{self, ...}: {
  flake.nixosModules.hosts--debug--diagnose = {...}: {
    # Diagnose
    # Enable persistent logging
    services.journald.extraConfig = ''
      Storage=persistent
    '';

    # Enable crash dumps
    systemd.coredump.enable = true;

    # Kernel parameters for debugging
    boot.kernelParams = [
      "panic=10" # Auto-reboot after 10 seconds
      "oops=panic" # Treat oops as panics
    ];

    # Enable kdump for crash analysis
    boot.crashDump.enable = true;

    # Extra logging
    boot.consoleLogLevel = 7;
  };
}
