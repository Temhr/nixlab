{ config, lib, pkgs, ... }: {

    home.file = {
    ".local/share/applications/EA-anki.desktop".text = ''
      [Desktop Entry]
      Name=Anki
      Comment=Spaced repetition flashcard program
      Exec=konsole -e nix run nixpkgs#anki-bin
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-audacity.desktop".text = ''
      [Desktop Entry]
      Name=Audacity
      Comment=Sound editor with graphical UI
      Exec=konsole -e nix run nixpkgs#audacity
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-darktable.desktop".text = ''
      [Desktop Entry]
      Name=Darktable
      Comment=Virtual lighttable and darkroom for photographers
      Exec=konsole -e nix run nixpkgs#darktable
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-gimp.desktop".text = ''
      [Desktop Entry]
      Name=Gimp
      Comment=GNU Image Manipulation Program
      Exec=konsole -e nix run nixpkgs#gimp3-with-plugins
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-inkscape.desktop".text = ''
      [Desktop Entry]
      Name=Inkscape
      Comment=Vector graphics editor
      Exec=konsole -e nix run nixpkgs#inkscape-with-extensions
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-kdenlive.desktop".text = ''
      [Desktop Entry]
      Name=Kdenlive
      Comment=Free and open source video editor, based on MLT Framework and KDE Frameworks
      Exec=konsole -e nix run nixpkgs#kdePackages.kdenlive
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-krita.desktop".text = ''
      [Desktop Entry]
      Name=Krita
      Comment=Free and open source painting application
      Exec=konsole -e nix run nixpkgs#krita
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-media-downloader.desktop".text = ''
      [Desktop Entry]
      Name=Media-downloader
      Comment=Qt/C++ GUI front end for yt-dlp and others
      Exec=konsole -e nix run nixpkgs#media-downloader
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';

    ".local/share/applications/EA-openshot.desktop".text = ''
      [Desktop Entry]
      Name=Openshot
      Comment=Free, open-source video editor
      Exec=konsole -e nix run nixpkgs#openshot-qt
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Ephemeral-App;
    '';
  };
}
