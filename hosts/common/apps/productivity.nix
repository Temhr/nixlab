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
          type = lib.types.enum ["none" "libreoffice" "collabora" "both"];
          default = "none";
          description = "Which office suite to install: libreoffice, collabora, both, or none";
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf config.calibre.enable {
        environment.systemPackages = with pkgs; [calibre]; # Comprehensive e-book software
      })
      (lib.mkIf (cfg.suite == "libreoffice" || cfg.suite == "both") {
        environment.systemPackages = with pkgs; [libreoffice-stable]; # Comprehensive, professional-quality productivity suite
      })
      (lib.mkIf (cfg.suite == "collabora" || cfg.suite == "both") {
        environment.systemPackages = with pkgs; [stable.collabora-desktop]; # Collaborative Office for desktop, based on LibreOffice technology
      })
      (lib.mkIf config.logseq.enable {
        environment.systemPackages = with pkgs; [logseq]; # Privacy-first, open-source knowledge management
      })
    ];
  };
}
