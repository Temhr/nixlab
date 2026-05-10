{...}: {
  flake.nixosModules.nsops--home-assistant = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homeassistant-custom;
  in {
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
      assertions = [
        {
          assertion = config.services.homeassistant-custom ? enable;
          message = "nsops--home-assistant requires servc--home-assistant-nixlab to also be imported";
        }
      ];

      sops.secrets.HA_SECRETS_YAML = {
        sopsFile = cfg.secretsFile;
        owner = "hass";
        restartUnits = ["home-assistant.service"];
      };

      services.homeassistant-custom.secretsYamlFile =
        config.sops.secrets.HA_SECRETS_YAML.path;
    };
  };
}
