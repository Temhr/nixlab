{...}: {
  flake.homeModules.temhr-nixace-extra = {pkgs, ...}: {
    # Let home Manager install and manage itself.
    programs.home-manager.enable = true;

    home.packages = with pkgs; [
      # steam
    ];

    home.sessionVariables = {
    };
  };
}
