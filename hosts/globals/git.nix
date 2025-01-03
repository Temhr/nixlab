{ config, lib, pkgs, ... }: {


  options = {
      github-desktop = {
          enable = lib.mkEnableOption "enables github-desktop";
      };
  };

  config = lib.mkMerge [
      (lib.mkIf config.github-desktop.enable {
        environment.systemPackages = [ pkgs.github-desktop ]; #GUI for managing Git and GitHub
      })
  ];

  environment.systemPackages = with pkgs; [
    git-credential-keepassxc #Helper that allows Git (and shell scripts) to use KeePassXC as credential store
  ];
  programs.git.enable = true;  #Distributed version control system

}
