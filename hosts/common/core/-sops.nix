{self, ...}: {
  flake.nixosModules.hosts--core--sops = {...}: {
    # Global SOPS configuration for all hosts
    sops = {
      # Age key location (same for all hosts)
      age.keyFile = "/var/lib/sops-nix/key.txt";

      # Default format for all secrets
      defaultSopsFormat = "yaml";
    };
  };
}
