# modules/maintenance-monitoring.nix
# Modular maintenance monitoring that integrates with existing Prometheus/Grafana/Loki
# Usage: Import this module and enable with: services.maintenance-monitoring.enable = true;

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.maintenance-monitoring;
  
  # Alert rules as importable JSON
  alertRulesJson = pkgs.writeText "maintenance-alerts.json" (builtins.toJSON {
    groups = import ./alert-rules.nix;
  });
  
  # Grafana dashboard as importable JSON
  maintenanceDashboard = pkgs.writeText "maintenance-dashboard.json" 
    (builtins.readFile ./grafana-dashboard.json);
  
  # Maintenance logger script
  maintenanceLogger = pkgs.writeScriptBin "maintenance-log" ''
    #!${pkgs.bash}/bin/bash
    ${builtins.readFile ./maintenance-logger.sh}
  '';

in {
  options.services.maintenance-monitoring = {
    enable = mkEnableOption "maintenance monitoring system";
    
    # Exporter configuration
    exporters = {
      node = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable node_exporter for system metrics";
        };
        port = mkOption {
          type = types.port;
          default = 9100;
          description = "Port for node_exporter";
        };
      };
      
      systemd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable systemd exporter for service monitoring";
        };
        port = mkOption {
          type = types.port;
          default = 9558;
          description = "Port for systemd exporter";
        };
      };
      
      blackbox = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable blackbox exporter for network probing";
        };
        port = mkOption {
          type = types.port;
          default = 9115;
          description = "Port for blackbox exporter";
        };
        targets = {
          http = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "https://example.com" "https://app.example.com" ];
            description = "HTTP targets to monitor";
          };
          icmp = mkOption {
            type = types.listOf types.str;
            default = [ "8.8.8.8" "1.1.1.1" ];
            description = "ICMP targets to ping";
          };
          ssl = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "https://example.com" ];
            description = "SSL certificate targets to monitor";
          };
        };
      };
      
      smartctl = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable SMARTCTL exporter for disk health";
        };
        port = mkOption {
          type = types.port;
          default = 9633;
          description = "Port for smartctl exporter";
        };
        devices = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "/dev/sda" "/dev/sdb" "/dev/nvme0n1" ];
          description = "Disk devices to monitor";
        };
      };
      
      backup = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable custom backup status exporter";
        };
        timestampFile = mkOption {
          type = types.str;
          default = "/var/backups/last_backup_timestamp";
          description = "File containing last backup timestamp";
        };
        sizeFile = mkOption {
          type = types.str;
          default = "/var/backups/last_backup_size";
          description = "File containing last backup size in bytes";
        };
      };
    };
    
    # Prometheus integration
    prometheus = {
      scrapeConfigs = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = "Generated Prometheus scrape configs (read-only, for reference)";
        readOnly = true;
      };
      
      alertRules = mkOption {
        type = types.path;
        default = alertRulesJson;
        description = "Path to alert rules JSON file";
        readOnly = true;
      };
    };
    
    # Grafana integration
    grafana = {
      dashboard = mkOption {
        type = types.path;
        default = maintenanceDashboard;
        description = "Path to maintenance dashboard JSON";
        readOnly = true;
      };
      
      provisionPath = mkOption {
        type = types.str;
        default = "/var/lib/grafana/dashboards/maintenance";
        description = "Path where dashboard will be provisioned";
      };
    };
    
    # Loki/Promtail integration
    loki = {
      maintenanceLogPath = mkOption {
        type = types.str;
        default = "/var/log/maintenance.log";
        description = "Path to maintenance log file";
      };
      
      scrapeConfig = mkOption {
        type = types.attrs;
        default = {};
        description = "Generated Promtail scrape config for maintenance logs";
        readOnly = true;
      };
    };
    
    # Periodic tasks
    periodicTasks = {
      zfs = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable automatic ZFS scrub timer";
        };
        pools = mkOption {
          type = types.listOf types.str;
          default = [ "tank" ];
          description = "ZFS pools to scrub";
        };
        schedule = mkOption {
          type = types.str;
          default = "weekly";
          description = "Systemd calendar expression for scrub schedule";
        };
      };
      
      smart = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable automatic SMART extended tests";
        };
        devices = mkOption {
          type = types.listOf types.str;
          default = [];
          example = [ "/dev/sda" "/dev/sdb" ];
          description = "Devices to test";
        };
        schedule = mkOption {
          type = types.str;
          default = "monthly";
          description = "Systemd calendar expression for SMART test schedule";
        };
      };
    };
  };
  
  config = mkIf cfg.enable {
    # ═══════════════════════════════════════════════════════════
    # EXPORTERS CONFIGURATION
    # ═══════════════════════════════════════════════════════════
    
    services.prometheus.exporters = {
      node = mkIf cfg.exporters.node.enable {
        enable = true;
        port = cfg.exporters.node.port;
        enabledCollectors = [
          "systemd"
          "processes"
          "cpu"
          "meminfo"
          "diskstats"
          "filesystem"
          "netdev"
          "hwmon"
          "thermal_zone"
          "loadavg"
        ];
        extraFlags = [
          "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|run)($|/)"
          "--collector.textfile.directory=/var/lib/node_exporter"
        ];
      };
      
      systemd = mkIf cfg.exporters.systemd.enable {
        enable = true;
        port = cfg.exporters.systemd.port;
      };
      
      blackbox = mkIf cfg.exporters.blackbox.enable {
        enable = true;
        port = cfg.exporters.blackbox.port;
        configFile = pkgs.writeText "blackbox.yml" ''
          modules:
            http_2xx:
              prober: http
              timeout: 5s
              http:
                valid_status_codes: []
                method: GET
                preferred_ip_protocol: "ip4"
                
            icmp:
              prober: icmp
              timeout: 5s
              icmp:
                preferred_ip_protocol: "ip4"
                
            tcp_connect:
              prober: tcp
              timeout: 5s
        '';
      };
      
      smartctl = mkIf cfg.exporters.smartctl.enable {
        enable = true;
        port = cfg.exporters.smartctl.port;
        devices = cfg.exporters.smartctl.devices;
      };
    };
    
    # ═══════════════════════════════════════════════════════════
    # PROMETHEUS SCRAPE CONFIGS (for importing)
    # ═══════════════════════════════════════════════════════════
    
    services.maintenance-monitoring.prometheus.scrapeConfigs = let
      mkScrapeConfig = name: port: {
        job_name = name;
        static_configs = [{
          targets = [ "localhost:${toString port}" ];
          labels = {
            alias = config.networking.hostName;
          };
        }];
      };
      
      blackboxScrapeConfig = module: targets: {
        job_name = "blackbox-${module}";
        metrics_path = "/probe";
        params.module = [ module ];
        static_configs = [{ inherit targets; }];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            replacement = "localhost:${toString cfg.exporters.blackbox.port}";
            target_label = "__address__";
          }
        ];
      };
      
    in
      optional cfg.exporters.node.enable (mkScrapeConfig "node" cfg.exporters.node.port)
      ++ optional cfg.exporters.systemd.enable (mkScrapeConfig "systemd" cfg.exporters.systemd.port)
      ++ optional cfg.exporters.smartctl.enable (mkScrapeConfig "smartctl" cfg.exporters.smartctl.port)
      ++ optional (cfg.exporters.blackbox.enable && cfg.exporters.blackbox.targets.http != [])
        (blackboxScrapeConfig "http_2xx" cfg.exporters.blackbox.targets.http)
      ++ optional (cfg.exporters.blackbox.enable && cfg.exporters.blackbox.targets.icmp != [])
        (blackboxScrapeConfig "icmp" cfg.exporters.blackbox.targets.icmp)
      ++ optional (cfg.exporters.blackbox.enable && cfg.exporters.blackbox.targets.ssl != [])
        (blackboxScrapeConfig "http_2xx" cfg.exporters.blackbox.targets.ssl);
    
    # ═══════════════════════════════════════════════════════════
    # CUSTOM BACKUP EXPORTER
    # ═══════════════════════════════════════════════════════════
    
    systemd.services.backup-status-exporter = mkIf cfg.exporters.backup.enable {
      description = "Backup Status Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        ExecStart = pkgs.writeShellScript "backup-exporter" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          
          METRICS_DIR="/var/lib/node_exporter"
          METRICS_FILE="$METRICS_DIR/backup_metrics.prom"
          
          mkdir -p "$METRICS_DIR"
          
          while true; do
            {
              # Last backup timestamp
              if [[ -f "${cfg.exporters.backup.timestampFile}" ]]; then
                LAST_BACKUP=$(cat "${cfg.exporters.backup.timestampFile}")
                echo "backup_job_last_success_timestamp $LAST_BACKUP"
              fi
              
              # Last backup size
              if [[ -f "${cfg.exporters.backup.sizeFile}" ]]; then
                BACKUP_SIZE=$(cat "${cfg.exporters.backup.sizeFile}")
                echo "backup_job_size_bytes $BACKUP_SIZE"
              fi
            } > "$METRICS_FILE.tmp"
            
            mv "$METRICS_FILE.tmp" "$METRICS_FILE"
            sleep 300  # Update every 5 minutes
          done
        '';
      };
    };
    
    # ═══════════════════════════════════════════════════════════
    # LOKI/PROMTAIL INTEGRATION
    # ═══════════════════════════════════════════════════════════
    
    # Create maintenance log file
    systemd.tmpfiles.rules = [
      "f ${cfg.loki.maintenanceLogPath} 0666 root root - -"
    ];
    
    # Generate Promtail scrape config
    services.maintenance-monitoring.loki.scrapeConfig = {
      job_name = "maintenance";
      static_configs = [{
        targets = [ "localhost" ];
        labels = {
          job = "maintenance-log";
          host = config.networking.hostName;
          __path__ = cfg.loki.maintenanceLogPath;
        };
      }];
      pipeline_stages = [
        {
          json = {
            expressions = {
              timestamp = "timestamp";
              level = "level";
              section = "section";
              task = "task";
              status = "status";
            };
          };
        }
        {
          labels = {
            level = "";
            section = "";
            status = "";
          };
        }
      ];
    };
    
    # ═══════════════════════════════════════════════════════════
    # GRAFANA DASHBOARD PROVISIONING
    # ═══════════════════════════════════════════════════════════
    
    # Create dashboard directory
    systemd.tmpfiles.rules = [
      "d ${cfg.grafana.provisionPath} 0755 grafana grafana - -"
    ];
    
    # Copy dashboard to provision path
    system.activationScripts.maintenance-dashboard = ''
      mkdir -p ${cfg.grafana.provisionPath}
      cp ${cfg.grafana.dashboard} ${cfg.grafana.provisionPath}/maintenance.json
      chown -R grafana:grafana ${cfg.grafana.provisionPath}
    '';
    
    # ═══════════════════════════════════════════════════════════
    # PERIODIC MAINTENANCE TASKS
    # ═══════════════════════════════════════════════════════════
    
    # ZFS Scrub
    systemd.services.zfs-scrub = mkIf cfg.periodicTasks.zfs.enable {
      description = "ZFS Scrub";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "zfs-scrub" ''
          #!${pkgs.bash}/bin/bash
          ${concatMapStringsSep "\n" (pool: 
            "${pkgs.zfs}/bin/zpool scrub ${pool}"
          ) cfg.periodicTasks.zfs.pools}
        '';
      };
    };
    
    systemd.timers.zfs-scrub = mkIf cfg.periodicTasks.zfs.enable {
      description = "ZFS Scrub Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.periodicTasks.zfs.schedule;
        Persistent = true;
      };
    };
    
    # SMART Tests
    systemd.services.smart-test = mkIf cfg.periodicTasks.smart.enable {
      description = "SMART Extended Test";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "smart-test" ''
          #!${pkgs.bash}/bin/bash
          ${concatMapStringsSep "\n" (device:
            "${pkgs.smartmontools}/bin/smartctl -t long ${device}"
          ) cfg.periodicTasks.smart.devices}
        '';
      };
    };
    
    systemd.timers.smart-test = mkIf cfg.periodicTasks.smart.enable {
      description = "SMART Test Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.periodicTasks.smart.schedule;
        Persistent = true;
      };
    };
    
    # ═══════════════════════════════════════════════════════════
    # MAINTENANCE LOGGER SCRIPT
    # ═══════════════════════════════════════════════════════════
    
    environment.systemPackages = [
      maintenanceLogger
      pkgs.jq  # Required by maintenance-log script
    ];
    
    # ═══════════════════════════════════════════════════════════
    # FIREWALL RULES
    # ═══════════════════════════════════════════════════════════
    
    networking.firewall.interfaces = mkIf config.networking.firewall.enable {
      # Allow exporters on internal interface (customize for your network)
      "${config.networking.defaultGateway.interface or "eth0"}" = {
        allowedTCPPorts = 
          optional cfg.exporters.node.enable cfg.exporters.node.port
          ++ optional cfg.exporters.systemd.enable cfg.exporters.systemd.port
          ++ optional cfg.exporters.blackbox.enable cfg.exporters.blackbox.port
          ++ optional cfg.exporters.smartctl.enable cfg.exporters.smartctl.port;
      };
    };
  };
}
