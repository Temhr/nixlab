{...}: {
  flake.nixosModules.nsops--ollama = {
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
          message = "nsops--ollama requires servc--ollama to also be imported";
        }
      ];

      sops.secrets.WEBUI_SECRET_KEY = {
        sopsFile = cfg.secretsFile;
        owner = cfg.webuiUser;
        group = cfg.webuiGroup;
        restartUnits = ["open-webui.service"];
      };

      services.ollama-stack.webuiSecretKeyFile =
        config.sops.secrets.WEBUI_SECRET_KEY.path;
    };
  };
}
