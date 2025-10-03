{ pkgs, ... }:
let
  repastShells = import ./repast.nix { inherit pkgs; };
in
{

  default = import ./default-shell.nix { inherit pkgs; };
  rust = import ./rust.nix { inherit pkgs; };
  python = import ./python.nix { inherit pkgs; };
  web = import ./web.nix { inherit pkgs; };
  security = import ./security.nix { inherit pkgs; };
  minimal = import ./minimal.nix { inherit pkgs; };

  # Repast4Py agent-based modeling shells
  repast = repastShells.default;      # Default to CPU
  repast-cpu = repastShells.cpu;      # Explicit CPU version
  repast-gpu = repastShells.gpu;      # GPU version
}
