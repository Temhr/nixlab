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
      assertions = [
        {
          assertion = config.services.ollama-stack ? enable;
          message = "secrets--ollama requires servc--ollama to also be imported";
        }
      ];
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.WEBUI_SECRET_KEY = {
        sopsFile = cfg.secretsFile;
        owner = "open-webui";
        restartUnits = [ "open-webui.service" ];  # restart webui when secret rotates
      };

      services.ollama-stack.webuiSecretKeyFile =
        config.sops.secrets.WEBUI_SECRET_KEY.path;
    };
  };
}
