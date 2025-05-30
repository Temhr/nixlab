{ pkgs, ... }:

pkgs.mkShell {
  name = "web-dev";

  buildInputs = with pkgs; [
    # Node.js ecosystem
    nodejs
    npm
    yarn
    pnpm

    # Development tools
    typescript
    nodePackages.typescript-language-server
    nodePackages.prettier
    nodePackages.eslint

    # Build tools
    webpack
    vite

    # Browsers for testing
    chromium
  ];

  shellHook = ''
    echo "🌐 Web Development Environment"
    echo "Node version: $(node --version)"
    echo "NPM version: $(npm --version)"
    echo ""
    echo "Available tools:"
    echo "  - npm/yarn/pnpm: Package managers"
    echo "  - typescript: TypeScript compiler"
    echo "  - prettier: Code formatter"
    echo "  - eslint: Linter"
    echo "  - webpack/vite: Build tools"
  '';
}
