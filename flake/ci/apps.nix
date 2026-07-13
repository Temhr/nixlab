{self, ...}: {
  perSystem = {pkgs, ...}: {
    apps.build-all = {
      type = "app";
      meta.description = "Build all NixOS configurations";
      program = toString (pkgs.writeShellScript "build-all" ''
        set -e
        echo "Building all NixOS configurations..."
        ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (
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
