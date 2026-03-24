{inputs, ...}: {
  flake.overlays = import ../../overlays {inherit inputs;};
  flake.nixosModules.nixlab = import ../../modules/nixos;
  flake.homeModules.nixlab = import ../../modules/home-manager;
}
