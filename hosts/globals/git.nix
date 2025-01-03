{ config, lib, pkgs, ... }: {

  environment.systemPackages = with pkgs; [

    pkgs.github-desktop #GUI for managing Git and GitHub
    pkgs.git-credential-keepassxc #Helper that allows Git (and shell scripts) to use KeePassXC as credential store

  ];

  programs.git.enable = true;  #Distributed version control system

}
