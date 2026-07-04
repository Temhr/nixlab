{...}: {
  flake.nixosModules.nsops--wiki-js = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.wikijs-custom;
  in {
    imports = [self.nixosModules.servc--wiki-js-nixlab];
    options.services.wikijs-custom.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./wiki-js.yaml;
      defaultText = lib.literalExpression "./wiki-js.yaml";
      description = ''
        Path to the sops-encrypted wiki-js secrets file.
        Defaults to wiki-js.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.WIKIJS_SECRET = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["wiki-js.service"];
      };

      services.wikijs-custom.appSecretFile =
        config.sops.secrets.WIKIJS_SECRET.path;
    };
  };
}
