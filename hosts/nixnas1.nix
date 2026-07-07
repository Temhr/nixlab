{self, ...}: {
  flake.nixosConfigurations.nixnas1 = self.lib.mkHost {
    name = "nixnas1";
    modules = [
      # Hardware
      self.nixosModules.hardw--m720q-nas1
      # Host config
      self.nixosModules.hosts--nixnas1
      self.nixosModules.hosts--profl--base
      self.nixosModules.hosts--profl--nas
      # Services
      self.nixosModules.servc--syncthing-nixlab
    ];
  };
  flake.nixosModules.hosts--nixnas1 = {
    config,
    pkgs,
    ...
  }: {
    ## SELF-HOSTED SERVICES
    services.grafana-nixlab.extraDashboards = ["zfs-monitoring"];

    services.syncthing-nixlab = {
      enable = true;
      enableGuiAuth = false; # No username/password prompt
      user = "${config.nixlab.mainUser}";
      group = "users";
      guiAddress = "0.0.0.0";
      configDir = "/home/${config.nixlab.mainUser}/.config/syncthing";
      openFirewall = true;
      devices = {
        "nixnas2" = {
          id = "2PZM5WE-FIU62B2-HABKBHT-5D6S2KW-U2YDFGH-5OIM4I3-PC4OOZI-YGBVHAQ";
          addresses = ["dynamic"];
          introducer = false;
        };
        "Pixel 8 Pro" = {
          id = "DWVLZ6M-TP7GD2I-3NEQ3YT-FWXHW4I-PRRY67U-MNVJ76F-NZFWNT7-6KUQLAF";
          addresses = ["dynamic"];
        };
        "Pixel 3a XL" = {
          id = "4CCPARZ-D55MZPY-OMRVLQL-YAQJFKY-5RZXAFQ-MZJ4VSC-E5ZS7VQ-VRCFGAY";
          addresses = ["dynamic"];
        };
      };
      folders = {
        "mirror" = {
          path = "/mirror";
          id = "mirror";
          label = "mirror";
          devices = ["nixnas2"];
          type = "sendreceive"; # or "sendonly" or "receiveonly" or "sendreceive"
        };
        "Phone media" = {
          path = "/mirror/phshare/photos";
          id = "Phone media";
          label = "Phone media";
          devices = ["Pixel 8 Pro" "Pixel 3a XL"];
          type = "sendreceive"; # or "sendonly" or "receiveonly" or "sendreceive"
        };
        "Docs" = {
          path = "/mirror/phshare/docs";
          id = "Docs";
          label = "Docs";
          devices = ["Pixel 8 Pro" "Pixel 3a XL"];
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
