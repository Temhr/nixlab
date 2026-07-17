{inputs, ...}: {
  flake.nixosModules.servc--hermes-nixlab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.nixlab-hermes;
  in {
    imports = [inputs.hermes-agent.nixosModules.default];

    options.services.nixlab-hermes = {
      enable = lib.mkEnableOption "Hermes Agent (multi-agent supervisor/worker system)";

      model = lib.mkOption {
        type = lib.types.str;
        default = "ollama/llama3.1";
      };

      ollamaBaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
      };

      mcpServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };

      # Renamed from telegramEnvFile — same option, more accurate name now
      # that Matrix is the actual channel.
      messagingEnvFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };

      extraUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };

    config = lib.mkIf cfg.enable {
      services.hermes-agent = {
        enable = true;

        # Confirmed real option — pulls the "matrix" pyproject extra into
        # the sealed venv, per the module source (uv-resolved, no PYTHONPATH
        # patching).
        extraDependencyGroups = ["matrix"];

        settings = {
          inherit (cfg) model;
          approvals.mode = "smart";
          approvals.cron_mode = "deny";
          delegation.orchestrator_enabled = true;
          delegation.max_spawn_depth = 2;
          # NOTE: unverified key path, same caveat as messaging.telegram.enabled
          # last time — grep the venv before trusting this.
          messaging.matrix.enabled = true;
        };

        environment = {
          OLLAMA_API_BASE = cfg.ollamaBaseUrl;
        };

        mcpServers = cfg.mcpServers;

        environmentFiles = lib.optionals (cfg.messagingEnvFile != null) [
          (toString cfg.messagingEnvFile)
        ];
      };

      users.users = lib.mkMerge (
        lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
        (map (u: {${u} = {extraGroups = [config.services.hermes-agent.group];};})
          ([config.nixlab.mainUser] ++ cfg.extraUsers))
      );
    };
  };
}
