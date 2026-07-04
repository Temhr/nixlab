{...}: {
  flake.nixosModules.nsops--home-assistant = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.homeassistant-custom;
  in {
    imports = [self.nixosModules.servc--home-assistant-nixlab];
    options.services.homeassistant-custom.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./home-assistant.yaml;
      defaultText = lib.literalExpression "./home-assistant.yaml";
      description = ''
        Path to the sops-encrypted home-assistant secrets file.
        The decrypted content is installed verbatim as secrets.yaml in dataDir.
        Defaults to home-assistant.yaml co-located with this module.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.HA_SECRETS_YAML = {
        sopsFile = cfg.secretsFile;
        owner = config.users.users.hass.name;
        group = config.users.groups.hass.name;
        restartUnits = ["home-assistant.service"];
      };

      services.homeassistant-custom.secretsYamlFile =
        config.sops.secrets.HA_SECRETS_YAML.path;
    };
  };
}
