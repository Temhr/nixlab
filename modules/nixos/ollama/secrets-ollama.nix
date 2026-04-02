{...}: {
  flake.nixosModules.secrets--ollama = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.ollama-stack;
  in {
    options.services.ollama-stack.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./ollama.yaml;
      defaultText = lib.literalExpression "./ollama.yaml";
      description = ''
        Path to the sops-encrypted ollama secrets file.
        Defaults to ollama.yaml co-located with this module.
        Override per-host if needed.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.WEBUI_SECRET_KEY = {
        sopsFile = cfg.secretsFile;
        owner = "open-webui";
        # Makes it available as /run/secrets/WEBUI_SECRET_KEY
      };
    };
  };
}
