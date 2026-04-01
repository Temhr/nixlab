{...}: {
  perSystem = {pkgs, ...}: {
    devShells.default = pkgs.mkShell {
      name = "nixlab-dev";

      buildInputs = with pkgs; [
        # NixOS rebuild and inspection
        nixos-rebuild
        nix-tree # visualise the dependency graph of any derivation
        nvd # diff two NixOS generations side-by-side
        nix-output-monitor # prettier nix build output

        # Secret management
        sops
        age
        ssh-to-age

        # Code quality
        git
        alejandra
        deadnix
        statix

        # Disk management
        parted
      ];

      shellHook = ''
        echo "🚀 NixLab Development Environment"
        echo ""
        echo "NixOS tools:"
        echo "  nixos-rebuild   Rebuild and switch the current host"
        echo "  nix-tree        Visualise derivation dependency graph"
        echo "  nvd             Diff two NixOS generations"
        echo "  nom             Prettier nix build output (wrap: nom-build)"
        echo ""
        echo "Secrets:"
        echo "  sops            Edit encrypted secret files"
        echo "  age / ssh-to-age Manage age keys"
        echo ""
        echo "Code quality:"
        echo "  alejandra       Format Nix files"
        echo "  deadnix         Find unused Nix bindings"
        echo "  statix          Lint Nix anti-patterns"
        echo ""
        echo "Available shells:  nix develop .#<name>"
        echo "  default  rust  python  web  security  minimal"
        echo "  mesa  mesa-cpu  mesa-gpu"
        echo "  repast  repast-cpu  repast-gpu"
      '';
    };
  };
}
