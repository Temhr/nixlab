{ self, inputs, outputs, lib, config, self, ... }: {
  imports = [
    # Import home-manager's NixOS module
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager = {
    extraSpecialArgs = { inherit inputs outputs self; };
    users = {
      # Import your home-manager configuration based on hostname
      temhr = import ("${self}/home/temhr/" + "${config.networking.hostName}.nix");
    };
  };
}
