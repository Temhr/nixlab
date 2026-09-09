{...}: {
  flake.nixosModules.nsops--wifi-hotspot = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.wifi-hotspot-nixlab;
  in {
    imports = [self.nixosModules.servc--wifi-hotspot-nixlab];

    options.services.wifi-hotspot-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./wifi-hotspot.yaml;
      defaultText = lib.literalExpression "./wifi-hotspot.yaml";
      description = ''
        Path to the sops-encrypted hotspot secrets file, containing
        wifi_hotspot_password. Defaults to wifi-hotspot.yaml co-located
        with this module. All hosts enabling the hotspot share this one
        file/password unless overridden per-host.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.wifi_hotspot_password = {
        sopsFile = cfg.secretsFile;
        # Owner left as default (root): wifi-hotspot-<interface>.service has
        # no dedicated system user (it must write to
        # /etc/NetworkManager/system-connections/ as root, and holds no
        # persistent state), same exception as alertmanager in §11b.
        restartUnits = ["wifi-hotspot-${cfg.interface}.service"];
      };

      services.wifi-hotspot-nixlab.passwordFile =
        config.sops.secrets.wifi_hotspot_password.path;
    };
  };
}
