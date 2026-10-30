{...}: {
  flake.nixosModules.servc--host-exporters-nixlab = {
    config,
    lib,
    pkgs,
    nixlabLib,
    ...
  }: let
    cfg = config.services.host-exporters-nixlab;
    node = cfg.nodeExporter;

    collectorFlags = lib.concatStringsSep " " ([
        "--collector.pressure"
        "--collector.processes" # Process counts and states
        "--collector.systemd" # Systemd unit states and metrics
        "--collector.systemd.enable-restarts-metrics" # restart counters
        "--collector.systemd.unit-include=.+[.](service|timer)" # drop mount/scope/slice series
        "--collector.hwmon" # Hardware sensors (temp, voltage, fans)
        "--collector.netclass" # Network interface properties
        "--collector.netdev" # Network device statistics
        "--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys)($|/)"
        # NFS client mounts are not checked here; the exports are watched on the NAS (S29, Edit 7).
        "--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nfs|nfs4|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|erofs|sysfs|tracefs)$"
      ]
      ++ lib.optionals (node.textfileDir != null) [
        "--collector.textfile.directory=${node.textfileDir}"
      ]);
  in {
    options.services.host-exporters-nixlab = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "prometheus";
        description = "User the node exporter runs as. Created here if no other module defines it.";
      };

      nodeExporter = {
        enable = lib.mkEnableOption "Prometheus node exporter";
        port = lib.mkOption {
          type = lib.types.port;
          default = 9100;
          description = "Port of the node exporter.";
        };
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "localhost";
          description = "Address to bind. Agents bind their own address so the hub can scrape them.";
        };
        textfileDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "/var/lib/node_exporter";
          description = "Textfile collector directory (the maintenance exporter writes here).";
        };
      };

      smartctl = {
        enable = lib.mkEnableOption "smartctl (SMART) exporter";
        port = lib.mkOption {
          type = lib.types.port;
          default = 9633;
          description = "Port of the smartctl exporter.";
        };
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address to bind. Agents bind their own address so the hub can scrape them.";
        };
        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["/dev/sda" "/dev/nvme0n1"];
          description = "Disk devices to monitor (empty means scan).";
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf node.enable {
        # The prometheus module defines this user (and wins) on hubs; agents get this minimal one.
        users.users.${cfg.user} = lib.mkDefault {
          isSystemUser = true;
          group = cfg.user;
          description = "Prometheus exporters user";
        };
        users.groups.${cfg.user} = lib.mkDefault {};

        systemd.tmpfiles.rules = lib.optional (node.textfileDir != null) "d ${node.textfileDir} 0755 ${cfg.user} ${cfg.user} -";

        systemd.services.prometheus-node-exporter = {
          description = "Prometheus Node Exporter";
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          serviceConfig =
            nixlabLib.mkServiceHardening {
              writablePaths = [];
              extraHardening = true;
            }
            // {
              Type = "simple";
              User = cfg.user;
              Group = cfg.user;
              ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter " + "--web.listen-address=${node.listenAddress}:${toString node.port} " + collectorFlags;
              Restart = "on-failure";
              RestartSec = "10s";
              MemoryMax = "256M";
              TasksMax = "128";
              RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_NETLINK" "AF_UNIX"];
              # node_exporter's hwmon/pressure/systemd collectors hit syscalls outside @system-service
              # intermittently, so the syscall filter stays off.
              SystemCallFilter = "";
              # The timex collector needs adjtimex (read-only use); ProtectClock would block it and silently
              # kill the ClockDrift metrics. The pressure, vmstat and netstat collectors read /proc widely.
              ProtectClock = false;
              ProtectProc = "default";
              ProcSubset = "all";
            };
        };
      })

      (lib.mkIf cfg.smartctl.enable {
        services.prometheus.exporters.smartctl = {
          enable = true;
          port = cfg.smartctl.port;
          listenAddress = cfg.smartctl.listenAddress;
          devices = cfg.smartctl.devices;
        };

        systemd.services.prometheus-smartctl-exporter.serviceConfig = {
          AmbientCapabilities = ["CAP_SYS_RAWIO"];
          CapabilityBoundingSet = ["CAP_SYS_RAWIO"];
          DeviceAllow = ["/dev/sd* r" "/dev/nvme* r"];
          PrivateDevices = lib.mkForce false;
        };
      })
    ];
  };
}
