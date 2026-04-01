{...}: {
  perSystem = {pkgs, ...}: {
    devShells.minimal = pkgs.mkShell {
      name = "minimal-dev";

      buildInputs = with pkgs; [
        git
        curl
        wget
        jq
        yq-go # like jq but for YAML — useful alongside Nix configs
        tree
        htop
        ripgrep # faster grep, useful for searching configs
        fd # faster find
      ];

      shellHook = ''
        echo "⚡ Minimal Development Environment"
        echo "git  curl  wget  jq  yq  tree  htop  ripgrep  fd"
      '';
    };
  };
}
