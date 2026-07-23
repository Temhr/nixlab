# nixlab/stacks/agent-infra.nix
{self, ...}: {
  flake.nixosModules.stack--agent-infra = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.nixlab-agent-infra;
    hermesCfg = config.services.hermes-agent;

    # Every proper-prefix directory of `path`, shallowest first, EXCLUDING
    # `path` itself — e.g. for "/home/temhr/nixlab" this is
    # ["/home" "/home/temhr"]. These need +x (traversal) only, not +r,
    # so the hermes group can pass through without being able to list
    # unrelated sibling files.
    ancestorsOf = path: let
      parts = lib.filter (s: s != "") (lib.splitString "/" path);
      n = lib.length parts;
    in
      lib.genList (i: "/" + lib.concatStringsSep "/" (lib.take (i + 1) parts)) (n - 1);

    aclPerm =
      if cfg.gitWritable
      then "rwx"
      else "rx";

    # Non-recursive, append-only, execute-only ACL on each ancestor dir.
    traversalRules =
      lib.concatMap
      (repo: map (a: "a+ ${a} - - - - group:${hermesCfg.group}:x") (ancestorsOf repo))
      cfg.gitRepoPaths;

    # Recursive ACL on the repo itself, plus a matching *default* ACL so
    # files/commits created later inherit it too — this is what makes it
    # stay correct without re-running anything by hand.
    repoRules =
      map
      (repo: "A+ ${repo} - - - - group:${hermesCfg.group}:${aclPerm},default:group:${hermesCfg.group}:${aclPerm}")
      cfg.gitRepoPaths;
  in {
    imports = [
      self.nixosModules.nsops--hermes
    ];

    options.services.nixlab-agent-infra = {
      enable = lib.mkEnableOption "nixlab agent infrastructure (Hermes + local MCP tool servers)";

      fsAllowedPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["/data/agent-infra/workspace"];
        description = ''
          Directories the filesystem MCP server may read/write. Passed as
          positional args to @modelcontextprotocol/server-filesystem, which
          enforces the boundary itself at runtime. Each path is created (if
          missing) and owned directly by the hermes service user via
          tmpfiles — no ACL needed here since hermes already owns it outright.
        '';
      };

      gitRepoPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["/home/temhr/nixlab"];
        description = ''
          Git repositories the git MCP server can operate on. Each path
          becomes its own named MCP server (git-0, git-1, ...) since
          mcp-server-git takes exactly one --repository per process.

          Unlike fsAllowedPaths, these are typically pre-existing repos owned
          by another user (e.g. under /home/<you>), so this module grants the
          hermes user POSIX ACL access automatically at every activation/boot
          — read+traverse (or read+write+traverse if gitWritable = true) on
          the repo itself, recursively, plus execute-only traversal on every
          parent directory above it. Nothing to run by hand.
        '';
      };

      gitWritable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Grant the hermes user write access (not just read) to
          gitRepoPaths — needed only if the agent should be able to commit
          or push, not merely inspect history/diffs. Off by default.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      # npx (Node.js) is already on hermes-agent's wrapped PATH. uvx (from
      # uv) is not, and mcp-server-git needs it — add it explicitly.
      services.hermes-agent.extraPackages = [pkgs.uv];

      services.nixlab-hermes.mcpServers = lib.mkMerge (
        (lib.optional (cfg.fsAllowedPaths != []) {
          filesystem = {
            command = "npx";
            args = ["-y" "@modelcontextprotocol/server-filesystem"] ++ cfg.fsAllowedPaths;
          };
        })
        ++ [
          (lib.listToAttrs (lib.imap0 (i: repo: {
              name = "git-${toString i}";
              value = {
                command = "uvx";
                args = ["mcp-server-git" "--repository" repo];
              };
            })
            cfg.gitRepoPaths))
        ]
      );

      systemd.tmpfiles.rules =
        (map (p: "d ${p} 0750 ${hermesCfg.user} ${hermesCfg.group} -") cfg.fsAllowedPaths)
        ++ traversalRules
        ++ repoRules;
    };
  };
}
