{ inputs, self, ... }: {

  flake.overlays = import ../../overlays { inherit inputs; };
  flake.nixosModules = import ../../modules/nixos;
  flake.homeModules = import ../../modules/home-manager;

}
