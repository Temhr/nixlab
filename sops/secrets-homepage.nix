{...}: {
  flake.nixosModules.nsops--homepage = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homepage-nixlab;
  in {
    options.services.homepage-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./homepage.yaml;
      defaultText = lib.literalExpression "./homepage.yaml";
      description = ''
        Path to the sops-encrypted homepage secrets file.
        The decrypted content must be KEY=value env file lines.
        Defaults to homepage.yaml co-located with this module.
      '';
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homepage-nixlab ? enable;
          message = "nsops--homepage requires servc--homepage-nixlab to also be imported";
        }
      ];

      sops.secrets.HOMEPAGE_ENV = {
        sopsFile = cfg.secretsFile;
        owner = cfg.user;
        group = cfg.group;
        restartUnits = ["homepage.service"];
      };

      services.homepage-nixlab.environmentFile =
        config.sops.secrets.HOMEPAGE_ENV.path;
    };
  };
}
