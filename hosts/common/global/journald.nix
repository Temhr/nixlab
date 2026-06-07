{self, ...}: {
  flake.nixosModules.hosts--c-glo--journald = {...}: {
    services.journald.extraConfig = ''
      SystemMaxUse=100M
      SystemMaxFileSize=10M
      SystemMaxFiles=10
      MaxRetentionSec=1month
    '';
  };
}
