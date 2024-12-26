{ config, lib, pkgs, ... }: {

    options = {
        openSourceGames = {
            enable = lib.mkEnableOption "enables open-source games";
        };
        steam = {
            enable = lib.mkEnableOption "enables Steam";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.openSourceGames.enable {
          environment.systemPackages = with pkgs; [
            unstable.lutris  #Open Source gaming platform for GNU/Linux
            superTuxKart  #A Free 3D kart racing game
          ];
        })
        (lib.mkIf config.steam.enable {
          programs.steam = {
            enable = true;
            remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
            dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
            localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
          };
        })
    ];

}
