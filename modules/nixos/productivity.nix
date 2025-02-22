{ config, lib, pkgs, ... }: {

    options = {
        calibre = {
            enable = lib.mkEnableOption {
              description = "Enables Calibre";
              default = false;
            };
        };
        libreoffice = {
            enable = lib.mkEnableOption {
              description = "Enables LibreOffice";
              default = false;
            };
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
