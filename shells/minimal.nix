{pkgs, ...}:
pkgs.mkShell {
  name = "minimal-dev";

  buildInputs = with pkgs; [
    git
    curl
    wget
    jq
    tree
    htop
  ];

  shellHook = ''
    echo "⚡ Minimal Development Environment"
    echo "Just the basics - git, curl, wget, jq, tree, htop"
  '';
}
