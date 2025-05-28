# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    ../common/global
    ../common/optional
    ../../modules/home-manager
    ./auto-git-pull.nix
    ./auto-move-files.nix
  ];

  # Add stuff for your user as you see fit:
  home = {
    username = "temhr";
    homeDirectory = "/home/temhr";
    #Environment Variables
    sessionVariables = {
    };
    packages = with pkgs; [
      # steam
    ];
  };

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Git Config
  programs.git.enable = true;  #Distributed version control system
  programs.git.userName  = "Temhr";
  programs.git.userEmail = "9110264+Temhr@users.noreply.github.com";

  # Extra Browsers
  brave.enable = true;
  chrome.enable = true;
  #edge.enable = true;
  zen.enable = true;

  ## Extra Terminal Emulators
  #alacritty.enable = true;  #Cross-platform, GPU-accelerated terminal emulator
  ghostty.enable = true;  #fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration
  #kitty.enable = true;  #Modern, hackable, featureful, OpenGL based terminal emulator
  #konsole.enable = true;  #Terminal emulator by KDE

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
