{...}: {
  flake.homeModules.temhr-nixzen-extra = {pkgs, ...}: {
    # Let home Manager install and manage itself.
    programs.home-manager.enable = true;
    #firefox.enable = true;

    home.packages = with pkgs; [
      # steam
    ];

    home.sessionVariables = {
    };


    home-manager.verbose = true;                 # NixOS module option
    home-manager.users.temhr.systemd.user.startServices = "legacy";  # bypass sd-switch
  };
}
