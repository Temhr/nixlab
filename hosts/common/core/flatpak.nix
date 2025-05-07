{ pkgs, ... }: {
  services.flatpak.enable = true;  #Linux application sandboxing and distribution framework
  #Adds Flathub repository as default
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
