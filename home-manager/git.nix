{ config, lib, pkgs, ... }: {

  home.packages = with pkgs; [

    github-desktop  #GUI for managing Git and GitHub
    git-credential-keepassxc  #Helper that allows Git (and shell scripts) to use KeePassXC as credential store

  ];

  programs.git = {
    enable = true;  #Distributed version control system
    userName  = "temhr";
    userEmail = "temhr@example.com";
  };
  programs.lazygit.enable = true;  #A simple terminal UI for git commands

}
