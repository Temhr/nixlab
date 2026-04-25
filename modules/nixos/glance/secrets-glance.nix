{...}: {
  flake.nixosModules.nsops--glance = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.glance-nixlab;
  in {
    options.services.glance-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./glance.yaml;
      defaultText = lib.literalExpression "./glance.yaml";
      description = ''
        Path to the sops-encrypted glance secrets file.
        The decrypted content must be a KEY=value env file
        (one variable per line, no shell quoting needed for simple values).
        Defaults to glance.yaml co-located with this module.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.GLANCE_ENV = {
        sopsFile = cfg.secretsFile;
        owner = "glance";
        # sops-nix decrypts this as a bare multi-line string; the preStart
        # wrapper below converts it to a proper KEY=value env file format.
        restartUnits = ["glance.service"];
      };

      # The sops secret is a bare env file (KEY=value lines), so we can use
      # it directly as an EnvironmentFile.
      services.glance-nixlab.secretsEnvFile =
        config.sops.secrets.GLANCE_ENV.path;
    };
  };
}
