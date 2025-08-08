{ config, lib, pkgs, ... }: {

## One-time use applications downloaded into store and discarded afterward

  home.file = {

    ## Audacity
    ".local/share/applications/audacity.desktop".text = ''
      [Desktop Entry]
      Name=Audacity
      Comment=Sound editor with graphical UI
      Exec=konsole -e nix run nixpkgs#audacity
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=AudioVideo;Audio;AudioVideoEditing;Ephemeral-App;
    '';

     ## Davinci Resolve
    ".local/share/applications/davinci-resolve.desktop".text = ''
      [Desktop Entry]
      Name=Davinci Resolve
      Comment=Professional video editing, color, effects and audio post-processing
      Exec=konsole -e NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#davinci-resolve
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    /* ## darktable - doesn't work properly because dependency libsoup-2.74.3 is a security risk
    ".local/share/applications/darktable.desktop".text = ''
      [Desktop Entry]
      Name=Darktable
      Comment=Virtual lighttable and darkroom for photographers
      Exec=konsole -e nix run nixpkgs#darktable
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Graphics;Photography;RasterGraphics;Ephemeral-App;
    ''; */

    ## Gimp
    ".local/share/applications/gimp.desktop".text = ''
      [Desktop Entry]
      Name=Gimp
      Comment=GNU Image Manipulation Program
      Exec=konsole -e nix run nixpkgs#gimp3-with-plugins
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Graphics;RasterGraphics;2DGraphics;Ephemeral-App;
    '';

    ## Inkscape
    ".local/share/applications/inkscape.desktop".text = ''
      [Desktop Entry]
      Name=Inkscape
      Comment=Vector graphics editor
      Exec=konsole -e nix run nixpkgs#inkscape-with-extensions
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Graphics;VectorGraphics;2DGraphics;Ephemeral-App;
    '';

    ## Kdenlive
    ".local/share/applications/kdenlive.desktop".text = ''
      [Desktop Entry]
      Name=Kdenlive
      Comment=Free and open source video editor, based on MLT Framework and KDE Frameworks
      Exec=konsole -e nix run nixpkgs#kdePackages.kdenlive
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## Krita
    ".local/share/applications/krita.desktop".text = ''
      [Desktop Entry]
      Name=Krita
      Comment=Free and open source painting application
      Exec=konsole -e nix run nixpkgs#krita
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Graphics;2DGraphics;Painting;Ephemeral-App;
    '';

    ## Lutris
    ".local/share/applications/lutris.desktop".text = ''
      [Desktop Entry]
      Name=Lutris
      Comment=Open Source gaming platform for GNU/Linux
      Exec=konsole -e NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#lutris
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

    ## Media-downloader
    ".local/share/applications/media-downloader.desktop".text = ''
      [Desktop Entry]
      Name=Media-downloader
      Comment=Qt/C++ GUI front end for yt-dlp and others
      Exec=konsole -e nix run nixpkgs#media-downloader
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Network;FileTransfer;Video;Ephemeral-App;
    '';

    ## Openshot
    ".local/share/applications/openshot.desktop".text = ''
      [Desktop Entry]
      Name=Openshot
      Comment=Free, open-source video editor
      Exec=konsole -e nix run nixpkgs#openshot-qt
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## SuperTuxKart
    ".local/share/applications/superTuxKart.desktop".text = ''
      [Desktop Entry]
      Name=SuperTuxKart
      Comment=A Free 3D kart racing game
      Exec=konsole -e nix run nixpkgs#superTuxKart
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

  };
}
