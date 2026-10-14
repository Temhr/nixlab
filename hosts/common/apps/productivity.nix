{...}: {
  flake.nixosModules.hosts--apps--productivity = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.office;
  in {
    options = {
      calibre.enable = lib.mkEnableOption "Calibre";
      logseq.enable = lib.mkEnableOption "Logseq";

      office = {
        suite = lib.mkOption {
          type = lib.types.enum ["none" "calligra" "collabora" "libreoffice" "cc" "lca" "lco" "all"];
          default = "none";
          description = "Which office suite to install: calligra, collabora, libreoffice, mix, all, or none";
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.calibre.enable {
        environment.systemPackages = with pkgs; [calibre]; # Comprehensive e-book software
      })
      (lib.mkIf (cfg.suite == "calligra" || cfg.suite == "cc" || cfg.suite == "lca" || cfg.suite == "all") {
        environment.systemPackages = with pkgs; [kdePackages.calligra]; # Office and graphic art suite by KDE
      })
      (lib.mkIf (cfg.suite == "collabora" || cfg.suite == "cc" || cfg.suite == "all" || cfg.suite == "lco") {
        environment.systemPackages = with pkgs; [collabora-desktop]; # Collaborative Office for desktop, based on LibreOffice technology. BROKEN: https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name/co/collabora-desktop
      })
      (lib.mkIf (cfg.suite == "libreoffice" || cfg.suite == "all" || cfg.suite == "lca" || cfg.suite == "lco") {
        environment.systemPackages = with pkgs; [libreoffice-stable]; # Comprehensive, professional-quality productivity suite
      })
      (lib.mkIf config.logseq.enable {
        environment.systemPackages = with pkgs; [logseq]; # Privacy-first, open-source knowledge management
      })
    ];
  };
}
