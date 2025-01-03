{ config, lib, pkgs, ... }: {


  options = {
      github-desktop = {
          enable = lib.mkEnableOption "enables github-desktop";
      };
      git-credential-keepassxc = {
          enable = lib.mkEnableOption "enables git-credential-keepassxc";
          default = true;
      };
  };

  config = lib.mkMerge [
      (lib.mkIf config.github-desktop.enable {
        environment.systemPackages = [ pkgs.github-desktop ]; #GUI for managing Git and GitHub
        programs.git.enable = true;
      })

      (lib.mkIf config.git-credential-keepassxc.enable {
        environment.systemPackages = [ pkgs.git-credential-keepassxc ]; #Helper that allows Git (and shell scripts) to use KeePassXC as credential store
      })
      (lib.mkDefault programs.chromium.enable = true;)  #Distributed version control system

  ];

}
