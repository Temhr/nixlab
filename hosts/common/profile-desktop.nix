{self, ...}: {
  flake.nixosModules.hosts--profl--desktop = {
    config,
    pkgs,
    hostMeta ? {},
    ...
  }: {
    imports = [
      self.nixosModules.hosts--apps--development
      self.nixosModules.hosts--apps--education
      self.nixosModules.hosts--apps--games
      self.nixosModules.hosts--apps--media
      self.nixosModules.hosts--apps--productivity
      self.nixosModules.hosts--apps--virtualizations

      self.nixosModules.hosts--deskt--cache-tmpfs
      self.nixosModules.hosts--deskt--firefox
      self.nixosModules.hosts--deskt--flatpak
      self.nixosModules.hosts--deskt--gui-shells
      self.nixosModules.hosts--deskt--ignore-lid
    ];

    services.nixlab-monitoring = {
      openFirewall = false;
      access.interfaces = [hostMeta.wifiIface];
      # access.expose defaults to ["grafana" "ntfy"]. Add "prometheus" here if you still want its UI from the LAN.
    };

    ## Automatic login for this user
    services.displayManager.autoLogin.user = config.nixlab.mainUser;

    # Define your Flatpak packages here
    flatpakPackages = [
      "net.davidotek.pupgui2" # ProtonUp-Qt Install Wine- and Proton-based compatibility tools
    ];

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia # GPU usage monitor for NVIDIA graphics
    ];
  };
}
