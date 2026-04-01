{...}: {
  perSystem = {pkgs, ...}: {
    devShells.web = pkgs.mkShell {
      name = "web-dev";

      buildInputs = with pkgs; [
        # Node.js runtime and package managers
        nodejs_20 # LTS — use nodePackages_latest for bleeding edge
        nodePackages_latest.npm
        nodePackages_latest.yarn
        nodePackages_latest.pnpm

        # TypeScript and language tooling
        nodePackages_latest.typescript
        nodePackages_latest.typescript-language-server

        # Code quality
        nodePackages_latest.prettier
        nodePackages_latest.eslint

        # Useful extras
        nodePackages_latest.http-server # quick local static server
        jq # JSON manipulation
      ];

      shellHook = ''
        echo "🌐 Web Development Environment"
        echo "  Node: $(node --version)"
        echo "  npm:  $(npm --version)"
        echo ""
        echo "Package managers:  npm  yarn  pnpm"
        echo "Tooling:           typescript  prettier  eslint"
        echo "Utilities:         http-server  jq"
        echo ""
        echo "Tip: bundlers (vite, webpack, esbuild) are best"
        echo "     installed per-project via npm/pnpm."
      '';
    };
  };
}
