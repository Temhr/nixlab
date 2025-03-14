{ config, lib, pkgs, inputs, ... }:{

  options = {
      git = {
          enable = lib.mkEnableOption "enables git";
      };
  };

  config = lib.mkMerge [
    (lib.mkIf config.git.enable {

      home.packages = with pkgs; [
        git
        github-desktop  #GUI for managing Git and GitHub
        git-credential-keepassxc  #Helper that allows Git (and shell scripts) to use KeePassXC as credential store
      ];

      programs.git = {
        enable = true;  #Distributed version control system
        userName  = "Temhr";
        userEmail = "9110264+Temhr@users.noreply.github.com";
      };
      programs.lazygit.enable = true;  #A simple terminal UI for git commands
    })
  ];
}
