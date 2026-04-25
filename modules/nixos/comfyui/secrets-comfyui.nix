{...}: {
  flake.nixosModules.sops--comfyui = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.comfyui-p5000;
  in {
    options.services.comfyui-p5000.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./comfyui.yaml;
      defaultText = lib.literalExpression "./comfyui.yaml";
      description = ''
        Path to the sops-encrypted comfyui secrets file.
        Defaults to comfyui.yaml co-located with this module.
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      sops.secrets.HF_TOKEN = {
        sopsFile = cfg.secretsFile;
        owner = "comfyui";
        restartUnits = ["comfyui-models-download.service"];
      };

      services.comfyui-p5000.huggingFaceTokenFile =
        config.sops.secrets.HF_TOKEN.path;
    };
  };
}
