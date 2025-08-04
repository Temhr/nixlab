{ config, lib, pkgs, ... }: {

    home.file = {
    "local/share/applications/run-kittysay.desktop".text = ''
      [Desktop Entry]
      Name=Kittysay Hello
      Comment=Run kittysay with a test message
      Exec=konsole -e nix run nixpkgs#kittysay -- "test hello"
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Utility;
    '';

    "local/share/applications/run-kittysay2.desktop".text = ''
      [Desktop Entry]
      Name=Kittysay Hello 2
      Comment=Run kittysay with a test message 2
      Exec=konsole -e nix run nixpkgs#kittysay -- "test hello 2"
      Icon=utilities-terminal
      Terminal=false
      Type=Application
      Categories=Utility;
    '';
  };
}
