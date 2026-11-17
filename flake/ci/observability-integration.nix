{
  self,
  inputs,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    # Same three checks as before, run by the observability flake's own implementation
    # against nixlab's real hosts (one per nixpkgs channel). Names are unchanged.
    checks = lib.optionalAttrs (system == "x86_64-linux") (
      lib.foldl' (acc: host:
        acc
        // inputs.observability.lib.observabilityHostChecks {
          inherit pkgs;
          name = host;
          hostConfig = self.nixosConfigurations.${host}.config;
        }) {} ["nixnas1" "nixsun"]
    );
  };
}
