{ config, lib, pkgs, ... }: {

    options = {
        syncbase = {
            enable = lib.mkEnableOption "enables Syncthing on nixbase";
        };
        synctop = {
            enable = lib.mkEnableOption "enables Syncthing on nixtop";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.syncbase.enable {
            environment.systemPackages = [
                pkgs.kittysay
            ];
        })

        (lib.mkIf config.synctop.enable {
            environment.systemPackages = [
                pkgs.kittysay
            ];
        })
    ];

}
