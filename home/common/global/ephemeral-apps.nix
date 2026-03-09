{ config, lib, pkgs, ... }: {

## One-time use applications downloaded into store and discarded afterward

  home.file = {

    ## Audacity
    ".local/share/applications/audacity.desktop".text = ''
      [Desktop Entry]
      Name=Audacity ⚡ 🫨
      Comment=Sound editor with graphical UI
      Exec=bash -c "nix run nixpkgs-unstable#audacity & disown"
      Icon=audacity
      Terminal=false
      Type=Application
      Categories=AudioVideo;Audio;AudioVideoEditing;Ephemeral-App;
    '';

     ## Blender
    ".local/share/applications/blender-cuda.desktop".text = ''
      [Desktop Entry]
      Name=Blender CUDA ⚡ 🫨
      Comment=3D Creation/Animation/Publishing System
      Exec=bash -c "NIXPKGS_ALLOW_UNFREE=1 nix run --impure --expr '(import <nixpkgs-unstable> {}).blender.override {cudaSupport=true;}' & disown"
      Icon=blender
      Terminal=false
      Type=Application
      Categories=Graphics;3DGraphics;Ephemeral-App;
    '';

    /* ## darktable - doesn't work properly because dependency libsoup-2.74.3 is a security risk
    ".local/share/applications/darktable.desktop".text = ''
      [Desktop Entry]
      Name=Darktable ⚡ 🫨
      Comment=Unstable - Virtual lighttable and darkroom
      Exec=bash -c "nix run nixpkgs-unstable#darktable & disown"
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
      Exec=bash -c "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#davinci-resolve & disown"
      Icon=DaVinciResolve
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

     ## discord
    ".local/share/applications/discord.desktop".text = ''
      [Desktop Entry]
      Name=Discord ⚡ 🫨
      Comment=All-in-one cross-platform voice and text chat for gamers
      Exec=bash -c "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs-unstable#discord & disown"
      Icon=discord
      Terminal=false
      Type=Application
      Categories=AudioVideo;Network;Video;Ephemeral-App;
    '';

     ## Drawio
    ".local/share/applications/drawio.desktop".text = ''
      [Desktop Entry]
      Name=Drawio ⚡ 🫨
      Comment=Desktop version of draw.io for creating diagrams
      Exec=bash -c "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs-unstable#drawio & disown"
      Icon=drawio
      Terminal=false
      Type=Application
      Categories=Graphics;Ephemeral-App;
    '';

    ## Godot
    ".local/share/applications/godot.desktop".text = ''
      [Desktop Entry]
      Name=Godot ⚡ 🫨
      Comment=Free and Open Source 2D and 3D game engine
      Exec=bash -c "nix run nixpkgs-unstable#godot & disown"
      Icon=godot
      Terminal=false
      Type=Application
      Categories=Development;Ephemeral-App;
    '';

    ## Gimp
    ".local/share/applications/gimp.desktop".text = ''
      [Desktop Entry]
      Name=GIMP ⚡ 🫨
      Comment=GNU Image Manipulation Program
      Exec=bash -c "nix run nixpkgs-unstable#gimp3-with-plugins & disown"
      Icon=gimp
      Terminal=false
      Type=Application
      Categories=Graphics;RasterGraphics;2DGraphics;Ephemeral-App;
    '';

    ## Inkscape
    ".local/share/applications/inkscape.desktop".text = ''
      [Desktop Entry]
      Name=Inkscape ⚡ 🫨
      Comment=Vector graphics editor
      Exec=bash -c "nix run nixpkgs-unstable#inkscape-with-extensions & disown"
      Icon=inkscape
      Terminal=false
      Type=Application
      Categories=Graphics;VectorGraphics;2DGraphics;Ephemeral-App;
    '';

    ## Kdenlive
    ".local/share/applications/kdenlive.desktop".text = ''
      [Desktop Entry]
      Name=Kdenlive ⚡ 🫨
      Comment=Video editor based on MLT Framework
      Exec=bash -c "nix run nixpkgs-unstable#kdePackages.kdenlive & disown"
      Icon=kdenlive
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## Krita
    ".local/share/applications/krita.desktop".text = ''
      [Desktop Entry]
      Name=Krita ⚡ 🫨
      Comment=Free and open source painting application
      Exec=bash -c "nix run nixpkgs-unstable#krita & disown"
      Icon=krita
      Terminal=false
      Type=Application
      Categories=Graphics;2DGraphics;Painting;Ephemeral-App;
    '';

    ## Lutris
    ".local/share/applications/lutris.desktop".text = ''
      [Desktop Entry]
      Name=Lutris ⚡ 🫨
      Comment=Open Source gaming platform for GNU/Linux
      Exec=bash -c "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs-unstable#lutris & disown"
      Icon=lutris
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

    ## Media-downloader
    ".local/share/applications/media-downloader.desktop".text = ''
      [Desktop Entry]
      Name=Media Downloader ⚡ 🫨
      Comment=Qt/C++ GUI front end for yt-dlp
      Exec=bash -c "nix run nixpkgs-unstable#media-downloader & disown"
      Icon=media-downloader
      Terminal=false
      Type=Application
      Categories=Network;FileTransfer;Video;Ephemeral-App;
    '';

    ## Microsoft Edge
    ".local/share/applications/microsoft-edge.desktop".text = ''
      [Desktop Entry]
      Name=Microsoft Edge ⚡ 🫨
      Comment=Web browser from Microsoft
      Exec=bash -c "NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs-unstable#microsoft-edge & disown"
      Icon=microsoft-edge
      Terminal=false
      Type=Application
      Categories=Network;FileTransfer;Ephemeral-App;
    '';

    ## OBS Studio
    ".local/share/applications/obs-studio.desktop".text = ''
      [Desktop Entry]
      Name=OBS Studio ⚡ 🫨
      Comment=Free and open source software for video recording and live streaming
      Exec=bash -c "nix run nixpkgs-unstable#obs-studio & disown"
      Icon=obs-studio
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## Openshot
    ".local/share/applications/openshot.desktop".text = ''
      [Desktop Entry]
      Name=OpenShot ⚡ 🫨
      Comment=Free, open-source video editor
      Exec=bash -c "nix run nixpkgs-unstable#openshot-qt & disown"
      Icon=openshot-qt
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## SuperTuxKart
    ".local/share/applications/superTuxKart.desktop".text = ''
      [Desktop Entry]
      Name=SuperTuxKart ⚡ 🫨
      Comment=A Free 3D kart racing game
      Exec=bash -c "nix run nixpkgs-unstable#superTuxKart & disown"
      Icon=supertuxkart
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

    ## Zed Editor
    ".local/share/applications/zedEditor.desktop".text = ''
      [Desktop Entry]
      Name=Zed Editor ⚡ 🫨
      Comment=High-performance, multiplayer code editor from the creators of Atom and Tree-sitter
      Exec=bash -c "nix run nixpkgs-unstable#zed-editor-fhs & disown"
      Icon=zedEditor
      Terminal=false
      Type=Application
      Categories=Development;Utilities;Ephemeral-App;
    '';

  };
}
