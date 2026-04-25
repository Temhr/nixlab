{...}: {
  flake.nixosModules.sops--wiki-js = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.wikijs-custom;
  in {
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
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.WIKIJS_SECRET = {
        sopsFile = cfg.secretsFile;
        owner = "wiki-js";
        restartUnits = ["wiki-js.service"];
      };

      services.wikijs-custom.appSecretFile =
        config.sops.secrets.WIKIJS_SECRET.path;
    };
  };
}
