# A shell focused specifically on Nix/NixOS development and debugging.
# Separate from default so it does not bloat the standard dev environment.
{...}: {
  perSystem = {pkgs, ...}: {
    devShells.nix-dev = pkgs.mkShell {
      name = "nix-debug";

      buildInputs = with pkgs; [
        nix-tree # interactive dependency graph explorer
        nvd # diff two NixOS closures or generations
        nix-diff # low-level derivation diff
        nix-du # disk usage analysis of the Nix store
        nix-output-monitor # prettier build output
        nixpkgs-review # review nixpkgs PRs locally
        nix-prefetch # prefetch sources and compute hashes
        nix-prefetch-git # same for git sources
        alejandra # formatter
        deadnix # find dead bindings
        statix # lint anti-patterns
        nil # Nix language server
      ];

      shellHook = ''
        echo "🔧 Nix Development & Debugging Shell"
        echo ""
        echo "Inspection:"
        echo "  nix-tree <drv>     explore dependency graph interactively"
        echo "  nvd diff <old> <new>  diff two NixOS generations"
        echo "  nix-diff <drv1> <drv2>  low-level derivation diff"
        echo "  nix-du -s=1GiB     find large paths in the Nix store"
        echo ""
        echo "Development:"
        echo "  nil                Nix language server (use with your editor)"
        echo "  nix-prefetch-git   get hash for a git source"
        echo "  alejandra / deadnix / statix  format and lint"
      '';
    };
  };
}
