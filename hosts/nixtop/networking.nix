{ config, lib, pkgs, ... }:

{

  networking = {
    interfaces.wlo1 = {
      ipv4.addresses = [{
        address = "192.168.0.203";
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = "192.168.0.1";
      interface = "wlo1";
    };
  };

}
