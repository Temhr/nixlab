{
  self,
  inputs,
  ...
}: {
  perSystem = {pkgs, ...}: let
    inherit (inputs.nixpkgs) lib;
  in {
    apps.build-all = {
      type = "app";
      program = toString (pkgs.writeShellScript "build-all" ''
        set -e
        echo "Building all NixOS configurations..."
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (
            name: _:
              "nix build .#nixosConfigurations.${name}"
              + ".config.system.build.toplevel --no-link"
          )
          self.nixosConfigurations)}
        echo "All builds passed."
      '');
    };
  };
}
