{pkgs, ...}: let
  mesaShells = import ./mesa.nix {inherit pkgs;};
  repastShells = import ./repast.nix {inherit pkgs;};
in {
  # Mesa agent-based modeling shells
  mesa = mesaShells.default; # Default to CPU
  mesa-cpu = mesaShells.cpu; # Explicit CPU version
  mesa-gpu = mesaShells.gpu; # GPU version

  # Repast4Py agent-based modeling shells
  repast = repastShells.default; # Default to CPU
  repast-cpu = repastShells.cpu; # Explicit CPU version
  repast-gpu = repastShells.gpu; # GPU version
}
