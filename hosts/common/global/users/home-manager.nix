{ flakePath, inputs, outputs, lib, config, ... }: {
  imports = [
    # Import home-manager's NixOS module
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager = {
    extraSpecialArgs = { inherit inputs outputs flakePath; };
    users.temhr = import (flakePath + "/home/temhr/${config.networking.hostName}.nix");
  };
}
