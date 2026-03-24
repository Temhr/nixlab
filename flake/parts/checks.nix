{
  inputs,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    inherit (inputs.nixpkgs) lib;
  in {
    checks = {
      pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
        src = ./../..;
        hooks = {
          alejandra.enable = true;
          deadnix.enable = true;
          check-merge-conflicts.enable = true;
        };
      };

      build-check = pkgs.writeShellScriptBin "build-check" ''
        echo "Checking all NixOS configurations..."
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (
            name: _:
              "nix build .#nixosConfigurations.${name}"
              + ".config.system.build.toplevel --no-link"
          )
          self.nixosConfigurations)}
      '';

      host-validation = pkgs.runCommand "validate-hosts" {} ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (
            hostname: _:
              "[ -f ${../../hosts}/${hostname}.nix ] || "
              + "(echo 'Missing: hosts/${hostname}.nix' && exit 1)"
          )
          self.nixosConfigurations)}
        echo 'All host files exist' > $out
      '';
    };
  };
}
