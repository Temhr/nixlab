{ config, lib, pkgs, ... }: {

## One-time use applications downloaded into store and discarded afterward

  home.file = {

    ## Audacity
    ".local/share/applications/audacity.desktop".text = ''
      [Desktop Entry]
      Name=Audacity ⚡
      Comment=Sound editor with graphical UI
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#audacity; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; NIXPKGS_ALLOW_UNFREE=1 nix run --impure --expr '(import <nixpkgs> {}).blender.override {cudaSupport=true;}'; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#darktable; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#davinci-resolve; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=DaVinciResolve
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

     ## discord
    ".local/share/applications/discord.desktop".text = ''
      [Desktop Entry]
      Name=Discord ⚡
      Comment=All-in-one cross-platform voice and text chat for gamers
      Exec=ghostty -e bash -c "echo 'Launching...'; NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#discord; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=discord
      Terminal=false
      Type=Application
      Categories=AudioVideo;Network;Video;Ephemeral-App;
    '';

     ## Drawio
    ".local/share/applications/drawio.desktop".text = ''
      [Desktop Entry]
      Name=Drawio ⚡
      Comment=Desktop version of draw.io for creating diagrams
      Exec=ghostty -e bash -c "echo 'Launching...'; NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#drawio; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=drawio
      Terminal=false
      Type=Application
      Categories=Graphics;Ephemeral-App;
    '';

    ## Gimp
    ".local/share/applications/gimp.desktop".text = ''
      [Desktop Entry]
      Name=GIMP ⚡
      Comment=GNU Image Manipulation Program
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#gimp3-with-plugins; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#inkscape-with-extensions; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#kdePackages.kdenlive; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#krita; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#lutris; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#media-downloader; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=media-downloader
      Terminal=false
      Type=Application
      Categories=Network;FileTransfer;Video;Ephemeral-App;
    '';

    ## Microsoft Edge
    ".local/share/applications/microsoft-edge.desktop".text = ''
      [Desktop Entry]
      Name=Microsoft Edge ⚡
      Comment=Web browser from Microsoft
      Exec=ghostty -e bash -c "echo 'Launching...'; NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#microsoft-edge; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=microsoft-edge
      Terminal=false
      Type=Application
      Categories=Network;FileTransfer;Ephemeral-App;
    '';

    ## OBS Studio
    ".local/share/applications/obs-studio.desktop".text = ''
      [Desktop Entry]
      Name=OBS Studio ⚡
      Comment=Free and open source software for video recording and live streaming
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#obs-studio; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=obs-studio
      Terminal=false
      Type=Application
      Categories=AudioVideo;Video;AudioVideoEditing;Ephemeral-App;
    '';

    ## Openshot
    ".local/share/applications/openshot.desktop".text = ''
      [Desktop Entry]
      Name=OpenShot ⚡
      Comment=Free, open-source video editor
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#openshot-qt; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
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
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#superTuxKart; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=supertuxkart
      Terminal=false
      Type=Application
      Categories=Game;Ephemeral-App;
    '';

    ## Wine-Wayland
    ".local/share/applications/wine-wayland.desktop".text = ''
      [Desktop Entry]
      Name=Wine-Wayland ⚡
      Comment=Open Source implementation of the Windows API on top of X, OpenGL, and Unix
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#wine-wayland; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=wine-wayland
      Terminal=false
      Type=Application
      Categories=Utilities;Ephemeral-App;
    '';

    ## Winetricks
    ".local/share/applications/winetricks.desktop".text = ''
      [Desktop Entry]
      Name=Winetricks ⚡
      Comment=Script to install DLLs needed to work around problems in Wine
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#winetricks; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=winetricks
      Terminal=false
      Type=Application
      Categories=Utilities;Ephemeral-App;
    '';

    ## Zed Editor
    ".local/share/applications/zedEditor.desktop".text = ''
      [Desktop Entry]
      Name=Zed Editor ⚡
      Comment=High-performance, multiplayer code editor from the creators of Atom and Tree-sitter
      Exec=ghostty -e bash -c "echo 'Launching...'; nix run nixpkgs#zed-editor-fhs; echo; echo 'Terminal will close in 3 seconds (Press Enter to pause timer)...'; if timeout 3 bash -c 'read -r'; then echo 'Timer paused. Press Enter to close...'; read -r; fi"
      Icon=zedEditor
      Terminal=false
      Type=Application
      Categories=Development;Utilities;Ephemeral-App;
    '';

  };
}
