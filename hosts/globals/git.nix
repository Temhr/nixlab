{ config, lib, pkgs, ... }: {

  environment.systemPackages = with pkgs; [

    github-desktop  #GUI for managing Git and GitHub
    git-credential-keepassxc  #Helper that allows Git (and shell scripts) to use KeePassXC as credential store

  ];

  programs.git.enable = true;  #Distributed version control system
  programs.lazygit.enable = true;  #A simple terminal UI for git commands

}
