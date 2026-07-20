{self, ...}: {
  flake.nixosModules.stack--agent-infra = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.nixlab-agent-infra;
  in {
    imports = [
      self.nixosModules.nsops--hermes
      self.nixosModules.servc--mcp-fs-nixlab
      self.nixosModules.servc--mcp-git-nixlab
      self.nixosModules.servc--mcp-ssh-nixlab
      self.nixosModules.nsops--mcp-ssh
    ];

    options.services.nixlab-agent-infra = {
      enable = lib.mkEnableOption "nixlab agent infrastructure (Hermes supervisor + MCP tool servers)";
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/data/agent-infra";
      };
      ports.mcpFs = lib.mkOption {
        type = lib.types.port;
        default = 8210;
      };
      ports.mcpGit = lib.mkOption {
        type = lib.types.port;
        default = 8211;
      };
      ports.mcpSsh = lib.mkOption {
        type = lib.types.port;
        default = 8212;
      };
      fsAllowedPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      gitRepoPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      sshAllowedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };

    config = lib.mkIf cfg.enable {
      services.mcp-fs-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.mcpFs;
        listenAddress = cfg.listenAddress;
        allowedPaths = cfg.fsAllowedPaths;
      };
      services.mcp-git-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.mcpGit;
        listenAddress = cfg.listenAddress;
        repoPaths = cfg.gitRepoPaths;
      };
      services.mcp-ssh-nixlab = {
        enable = true;
        port = lib.mkDefault cfg.ports.mcpSsh;
        listenAddress = cfg.listenAddress;
        allowedHosts = cfg.sshAllowedHosts;
      };

      services.nixlab-hermes = {
        enable = true;
        mcpServers = {
          filesystem.url = "http://${cfg.listenAddress}:${toString cfg.ports.mcpFs}";
          git.url = "http://${cfg.listenAddress}:${toString cfg.ports.mcpGit}";
          ssh.url = "http://${cfg.listenAddress}:${toString cfg.ports.mcpSsh}";
        };
      };
    };
  };
}
