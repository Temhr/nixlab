{
  inputs,
  ...
}: {
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

      # Restored — wired through the confirmed `environment` option instead
      # of a guessed settings.* key.
      ollamaBaseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:11434";
        description = ''
          Passed to Hermes as OLLAMA_API_BASE via environment. Verify this
          is the env var name Hermes's Ollama provider actually reads —
          check `hermes setup` interactively or the provider docs if the
          connection doesn't establish.
        '';
      };

      mcpServers = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = {};
      };

      telegramEnvFile = lib.mkOption {
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

        settings = {
          inherit (cfg) model;
          approvals.mode = "smart";
          approvals.cron_mode = "deny";
          delegation.orchestrator_enabled = true;
          delegation.max_spawn_depth = 2;
        };

        environment = {
          OLLAMA_API_BASE = cfg.ollamaBaseUrl;
        };

        mcpServers = cfg.mcpServers;

        environmentFiles = lib.optionals (cfg.telegramEnvFile != null) [
          (toString cfg.telegramEnvFile)
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
