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
          ## Nix-specific
          alejandra.enable = true; #                   Nix formatter (opinionated, replaces nixfmt)
          deadnix.enable = true; #                     Removes unused Nix code (dead bindings/imports)
          #statix.enable = true; #                      Lints Nix anti-patterns (e.g. redundant rec, with abuse)
          #nil.enable = true; #                         LSP-based static analysis for Nix files

          ## Git safety
          check-merge-conflicts.enable = true; #       Blocks commits containing unresolved merge conflict markers
          forbid-new-submodules.enable = true; #       Prevents addition of new git submodules
          check-added-large-files.enable = true; #     Blocks commits adding files over the size threshold

          ## General file hygiene
          #end-of-file-fixer.enable = true; #           Ensures all files end with a single newline
          #trim-trailing-whitespace.enable = true; #    Strips trailing whitespace from all lines

          ## Multi-language formatting
          #prettier.enable = true; #                    Formats non-Nix files (JSON, YAML, Markdown, etc.)
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
    };
  };
}
