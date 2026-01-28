{ config, pkgs, lib, ... }:

let
  installCmd = lib.concatMapStringsSep "\n"
    (pkg: "flatpak install --noninteractive flathub ${pkg}")
    config.flatpakPackages;
in
{
  options = {
    flatpakPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of Flatpak packages to install from Flathub";
    };
  };

  config = {
    #Linux application sandboxing and distribution framework
    services.flatpak.enable = true;

    #Adds Flathub repository as default
    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      '';
      serviceConfig.Type = "oneshot";
      # Wait for network to be available before running
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };

    systemd.services.flatpak-installer = {
      wantedBy = [ "multi-user.target" ];
      after = [ "flatpak-repo.service" ];
      wants = [ "flatpak-repo.service" ];
      path = [ pkgs.flatpak ];
      script = installCmd;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    # Automatic Flatpak updates
    systemd.services.flatpak-updater = {
      description = "Update Flatpak packages";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak update --noninteractive
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

    systemd.timers.flatpak-updater = {
      description = "Update Flatpak packages daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Enable XDG portal for better desktop integration
    xdg.portal.enable = true;
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
