{...}: {
  flake.nixosModules.sops--homepage = {
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
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.HOMEPAGE_ENV = {
        sopsFile = cfg.secretsFile;
        # homepage-dashboard runs as a dedicated system user; adjust if yours differs
        owner = "homepage";
        restartUnits = ["homepage-dashboard.service"];
      };

      services.homepage-nixlab.environmentFile =
        config.sops.secrets.HOMEPAGE_ENV.path;
    };
  };
}
