{ config, lib, pkgs, ... }: {

    options = {
        calibre = {
            enable = lib.mkEnableOption "enables Calibre";
        };
        libreoffice = {
            enable = lib.mkEnableOption "enables LibreOffice";
        };
    };

    config = lib.mkMerge [
        (lib.mkIf config.calibre.enable {
          environment.systemPackages = [ pkgs.calibre ];  #Comprehensive e-book software
        })
        (lib.mkIf config.libreoffice.enable {
          environment.systemPackages = [ pkgs.libreoffice-fresh ];  #Comprehensive, professional-quality productivity suite
        })
    ];

}
