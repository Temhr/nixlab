{ config, lib, pkgs, ... }: {

    options = {
        discord = {
            enable = lib.mkEnableOption {
              description = "Enables discord";
              default = false;
            };
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.discord.enable {
            environment.systemPackages = with pkgs; [
                discord  #All-in-one cross-platform voice and text chat for gamers
            ];
        })
    ];

}
