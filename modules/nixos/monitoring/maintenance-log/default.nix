{...}: {
  # Exposed for flake/ci/monitoring-checks.nix (shellcheck).
  flake.lib.maintenanceLoggerScript = ./maintenance-logger.sh;

  flake.nixosModules.servc--maintenance-log-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.maintenance-log-nixlab;
  in {
    options.services.maintenance-log-nixlab = {
      enable = lib.mkEnableOption "maintenance task logging helper";

      logPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/log/maintenance.jsonl";
        description = "Path of the maintenance log (JSON lines). Must NOT end in .log or the /var/log/*.log pipeline would ingest it twice.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !(lib.hasSuffix ".log" cfg.logPath);
          message = "services.maintenance-log-nixlab.logPath must not end in .log (it would also be tailed by the /var/log/*.log pipeline and ingested twice).";
        }
      ];

      # Writable by wheel only: world-writable would let any local user forge audit entries.
      systemd.tmpfiles.rules = [
        "f ${cfg.logPath} 0664 root wheel - -"
        "z ${cfg.logPath} 0664 root wheel - -"
      ];

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "maintenance-log" ''
          export PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils pkgs.gawk pkgs.gnugrep]}:$PATH
          export MAINTENANCE_LOG=''${MAINTENANCE_LOG:-${lib.escapeShellArg cfg.logPath}}
          ${builtins.readFile ./maintenance-logger.sh}
        '')
        pkgs.jq
      ];
    };
  };
}
