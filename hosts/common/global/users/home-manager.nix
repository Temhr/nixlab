{ inputs, outputs, ... }: {
  imports = [
    # Import home-manager's NixOS module
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager = {
    extraSpecialArgs = { inherit inputs outputs self; };
    users = {
      # Import your home-manager configuration
      temhr = import ../../../../home/temhr/configuration.nix;
    };
  };
}
