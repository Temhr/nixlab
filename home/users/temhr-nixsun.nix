{...}: {
  flake.homeModules.temhr-nixsun-extra = {pkgs, ...}: {
    # Let home Manager install and manage itself.
    programs.home-manager.enable = true;
    firefox.enable = true;

    home.packages = with pkgs; [
      # steam
    ];

    home.sessionVariables = {
    };
  };
}
