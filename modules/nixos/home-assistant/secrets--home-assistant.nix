{...}: {
  flake.nixosModules.sops--home-assistant = {
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
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

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
