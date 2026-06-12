{self, ...}: {
  flake.nixosConfigurations.nixnas2 = self.lib.mkHost {
    name = "nixnas2";
    modules = [
      # Hardware
      self.nixosModules.hardw--m720q-nas2
      # Host config
      self.nixosModules.hosts--nixnas2
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--nas
      # Services
      self.nixosModules.servc--syncthing-nixlab
      #self.nixosModules.nsops--syncthing
    ];
  };
  flake.nixosModules.hosts--nixnas2 = {
    config,
    pkgs,
    ...
  }: {
    ## Shared system-wide user option
    nixlab.mainUser = "temhr";

    ## SELF-HOSTED SERVICES
    services.syncthing-nixlab = {
      enable = true;
      enableGuiAuth = false; # No username/password prompt
      user = "${config.nixlab.mainUser}";
      group = "users";
      guiAddress = "0.0.0.0";
      configDir = "/home/${config.nixlab.mainUser}/.config/syncthing";
      openFirewall = true;
      devices = {
        "nixnas1" = {
          id = "FLLLT4M-KQYRPWS-Q6F2RNK-FW4LQ3E-ENZKNBI-VP3PJ4Q-HYWCKP3-2RQM3AB";
          addresses = ["dynamic"];
          introducer = false;
        };
      };
      folders = {
        "mirror" = {
          path = "/mirror";
          id = "mirror";
          label = "mirror";
          devices = ["nixnas1"];
          type = "sendreceive"; # or "sendonly" or "receiveonly" or "sendreceive"
        };
      };
    };

    ## List packages installed in system profile. To search, run:
    ## $ nix search wget
    environment.systemPackages = with pkgs; [
    ];

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    system.stateVersion = "24.11";
  };
}
