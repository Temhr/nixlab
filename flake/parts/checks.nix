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
          alejandra.enable = true; #                   Nix formatter (opinionated, replaces nixfmt)
          deadnix.enable = true; #                     Removes unused Nix code (dead bindings/imports)
          #statix.enable = true; #                     Lints Nix anti-patterns (e.g. redundant rec, with abuse)
          #nil.enable = true; #                        LSP-based static analysis for Nix files
          #check-merge-conflicts.enable = true; #      Blocks commits containing unresolved merge conflict markers
          #forbid-new-submodules.enable = true; #      Prevents addition of new git submodules
          check-added-large-files.enable = true; #     Blocks commits adding files over the size threshold
          #end-of-file-fixer.enable = true; #          Ensures all files end with a single newline
          #trim-trailing-whitespace.enable = true; #   Strips trailing whitespace from all lines
          #prettier.enable = true; #                   Formats non-Nix files (JSON, YAML, Markdown, etc.)
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
