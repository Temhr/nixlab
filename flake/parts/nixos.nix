{...}: {
  # ───────────────────────────────────────────────────────────
  # MODULE REGISTRY — stable names, resilient wiring
  # ───────────────────────────────────────────────────────────
  flake.nixosModules = {
    cachix = import ../../cachix.nix;
  };
}
