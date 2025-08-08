{ config, lib, pkgs, ... }: {

## One-time use applications downloaded into store and discarded afterward

  home.file = {

    ## Audacity
    ".local/share/applications/audacity.desktop".text = ''
      [Desktop Entry]
      Name=Audacity ⚡
      Comment=Sound editor with graphical UI
      Exec=konsole -e nix run nixpkgs#audacity
      Icon=audacity
      Terminal=false
      Type=Application
      Categories=AudioVideo;Audio;AudioVideoEditing;Ephemeral-App;
    '';

     ## Blender
    ".local/share/applications/blender-cuda.desktop".text = ''
      [Desktop Entry]
      Name=Blender CUDA ⚡
      Comment=3D Creation/Animation/Publishing System
      Exec=env NIXPKGS_ALLOW_UNFREE=1 nix run --impure --expr "(import <nixpkgs> {}).blender.override {cudaSupport=true;}"
      Icon=blender
      Terminal=false
      Type=Application
      Categories=Graphics;3DGraphics;Ephemeral-App;
    '';

    /* ## darktable - doesn't work properly because dependency libsoup-2.74.3 is a security risk
    ".local/share/applications/darktable.desktop".text = ''
      [Desktop Entry]
      Name=Darktable ⚡
      Comment=Virtual lighttable and darkroom
      Exec=konsole -e nix run nixpkgs#darktable
      Icon=darktable
      Terminal=false
      Type=Application
      Categories=Graphics;Photography;RasterGraphics;Ephemeral-App;
    ''; */

     ## Davinci Resolve
    ".local/share/applications/davinci-resolve.desktop".text = ''
      [Desktop Entry]
      Name=DaVinci Resolve ⚡
      Comment=Professional video editing, color, effects and audio
      Exec=env NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#davinci-resolve
      Icon=DaVinciResolve
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## Gimp
    ".local/share/applications/gimp.desktop".text = ''
      [Desktop Entry]
      Name=GIMP ⚡
      Comment=GNU Image Manipulation Program
      Exec=konsole -e nix run nixpkgs#gimp3-with-plugins
      Icon=gimp
      Terminal=false
      Type=Application
      Categories=Graphics;RasterGraphics;2DGraphics;Ephemeral-App;
    '';

    ## Inkscape
    ".local/share/applications/inkscape.desktop".text = ''
      [Desktop Entry]
      Name=Inkscape ⚡
      Comment=Vector graphics editor
      Exec=konsole -e nix run nixpkgs#inkscape-with-extensions
      Icon=inkscape
      Terminal=false
      Type=Application
      Categories=Graphics;VectorGraphics;2DGraphics;Ephemeral-App;
    '';

    ## Kdenlive
    ".local/share/applications/kdenlive.desktop".text = ''
      [Desktop Entry]
      Name=Kdenlive ⚡
      Comment=Video editor based on MLT Framework
      Exec=konsole -e nix run nixpkgs#kdePackages.kdenlive
      Icon=kdenlive
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## Krita
    ".local/share/applications/krita.desktop".text = ''
      [Desktop Entry]
      Name=Krita ⚡
      Comment=Free and open source painting application
      Exec=konsole -e nix run nixpkgs#krita
      Icon=krita
      Terminal=false
      Type=Application
      Categories=Graphics;2DGraphics;Painting;Ephemeral-App;
    '';

    ## Lutris
    ".local/share/applications/lutris.desktop".text = ''
      [Desktop Entry]
      Name=Lutris ⚡
      Comment=Open Source gaming platform for GNU/Linux
      Exec=env NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#lutris
      Icon=lutris
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

    ## Media-downloader
    ".local/share/applications/media-downloader.desktop".text = ''
      [Desktop Entry]
      Name=Media Downloader ⚡
      Comment=Qt/C++ GUI front end for yt-dlp
      Exec=konsole -e nix run nixpkgs#media-downloader
      Icon=media-downloader
      Terminal=false
      Type=Application
      Categories=Network;FileTransfer;Video;Ephemeral-App;
    '';

    ## Openshot
    ".local/share/applications/openshot.desktop".text = ''
      [Desktop Entry]
      Name=OpenShot ⚡
      Comment=Free, open-source video editor
      Exec=konsole -e nix run nixpkgs#openshot-qt
      Icon=openshot-qt
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## SuperTuxKart
    ".local/share/applications/superTuxKart.desktop".text = ''
      [Desktop Entry]
      Name=SuperTuxKart ⚡
      Comment=A Free 3D kart racing game
      Exec=konsole -e nix run nixpkgs#superTuxKart
      Icon=supertuxkart
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

  };
}
