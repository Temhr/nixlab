{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus-custom;

  # Import the alerts configuration from alerts.nix
  alertRulesConfig = import ./alerts.nix;

  # ┌─────────────────────────────────────────────────────────┐
  # │ MAINTENANCE MONITORING INTEGRATION                      │
  # │ Import maintenance alert rules if enabled               │
  # └─────────────────────────────────────────────────────────┘
  maintenanceAlertRules = if cfg.maintenance.enable
    then import ./maintenance-alerts.nix
    else { groups = []; };

  # Merge your alerts with maintenance alerts
  combinedAlertRules = {
    groups = alertRulesConfig.groups ++ maintenanceAlertRules.groups;
  };

  # Convert alerts to JSON file (will be converted to YAML in preStart)
  alertRulesJsonFile = builtins.toFile "alerts.json"
    (builtins.toJSON combinedAlertRules);
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.prometheus-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Prometheus monitoring system";

      # OPTIONAL: Port to listen on (default: 9090)
      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Port for Prometheus to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      # Use "0.0.0.0" for access from other devices
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "prometheus.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Prometheus data (default: /var/lib/prometheus2)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/prometheus2";
        example = "/data/prometheus";
        description = "Directory for Prometheus time-series data";
      };

      # OPTIONAL: Data retention period (default: 15d)
      retention = lib.mkOption {
        type = lib.types.str;
        default = "15d";
        example = "30d";
        description = "How long to retain metrics data";
      };

      # OPTIONAL: Prometheus package to use (default: pkgs.prometheus)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.prometheus;
        defaultText = lib.literalExpression "pkgs.prometheus";
        description = "The Prometheus package to use";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Enable node exporter for system metrics (default: true)
      enableNodeExporter = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Prometheus Node Exporter for system metrics";
      };

      # ┌─────────────────────────────────────────────────────────┐
      # │ NEW: MAINTENANCE MONITORING OPTIONS                     │
      # └─────────────────────────────────────────────────────────┘
      maintenance = {
        enable = lib.mkEnableOption "maintenance monitoring exporters and alerts";

        exporters = {
          systemd = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable systemd exporter for service status monitoring";
          };

          blackbox = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable blackbox exporter for network probing";
            };
            httpTargets = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = [ "https://example.com" ];
              description = "HTTP targets to monitor";
            };
            icmpTargets = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "8.8.8.8" "1.1.1.1" ];
              description = "ICMP targets to ping";
            };
            sslTargets = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = [ "https://example.com" ];
              description = "SSL certificate targets to monitor";
            };
          };

          smartctl = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable SMARTCTL exporter for disk health";
            };
            devices = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              example = [ "/dev/sda" "/dev/nvme0n1" ];
              description = "Disk devices to monitor";
            };
          };

          backup = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable custom backup status exporter";
            };
            timestampFile = lib.mkOption {
              type = lib.types.str;
              default = "/var/backups/last_backup_timestamp";
              description = "File containing last backup timestamp";
            };
            sizeFile = lib.mkOption {
              type = lib.types.str;
              default = "/var/backups/last_backup_size";
              description = "File containing last backup size in bytes";
            };
          };
        };
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when the service is enabled
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # ----------------------------------------------------------------------------
    # DIRECTORY SETUP - Create necessary directories with proper permissions
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0770 prometheus prometheus -"
    ] ++ lib.optionals cfg.maintenance.enable [
      "d /var/lib/node_exporter 0755 prometheus prometheus -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system user for Prometheus
    # ----------------------------------------------------------------------------
    users.users.prometheus = {
      isSystemUser = true;
      group = "prometheus";
      home = cfg.dataDir;
      description = "Prometheus service user";
    };

    users.groups.prometheus = {};

    users.users.temhr.extraGroups = [ "prometheus" ];

    # ┌─────────────────────────────────────────────────────────┐
    # │ MAINTENANCE EXPORTERS                                   │
    # └─────────────────────────────────────────────────────────┘

    # Systemd Exporter
    services.prometheus.exporters.systemd = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.systemd) {
      enable = true;
      port = 9558;
    };

    # Blackbox Exporter
    services.prometheus.exporters.blackbox = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.blackbox.enable) {
      enable = true;
      port = 9115;
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

    # SMARTCTL Exporter
    services.prometheus.exporters.smartctl = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable) {
      enable = true;
      port = 9633;
      devices = cfg.maintenance.exporters.smartctl.devices;
      # Grant necessary capabilities to access SMART data
      # The exporter needs CAP_SYS_RAWIO to query disk SMART attributes
    };

    # Add prometheus user to disk group for SMART access
    users.users.prometheus = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable) {
      extraGroups = [ "disk" ];
    };

    # Override the systemd service to add capabilities
    systemd.services.prometheus-smartctl-exporter = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.smartctl.enable) {
      serviceConfig = {
        # Add capability to access raw disk devices
        AmbientCapabilities = [ "CAP_SYS_RAWIO" ];
        CapabilityBoundingSet = [ "CAP_SYS_RAWIO" ];
        # Allow access to /dev devices
        DeviceAllow = [ "/dev/sd* r" "/dev/nvme* r" ];
        PrivateDevices = lib.mkForce false;
      };
    };

    # Custom Backup Exporter
    systemd.services.backup-status-exporter = lib.mkIf (cfg.maintenance.enable && cfg.maintenance.exporters.backup.enable) {
      description = "Backup Status Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "prometheus";
        Group = "prometheus";
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
              if [[ -f "${cfg.maintenance.exporters.backup.timestampFile}" ]]; then
                LAST_BACKUP=$(cat "${cfg.maintenance.exporters.backup.timestampFile}")
                echo "backup_job_last_success_timestamp $LAST_BACKUP"
              fi

              if [[ -f "${cfg.maintenance.exporters.backup.sizeFile}" ]]; then
                BACKUP_SIZE=$(cat "${cfg.maintenance.exporters.backup.sizeFile}")
                echo "backup_job_size_bytes $BACKUP_SIZE"
              fi
            } > "$METRICS_FILE.tmp"

            mv "$METRICS_FILE.tmp" "$METRICS_FILE"
            sleep 300
          done
        '';
      };
    };

    # ----------------------------------------------------------------------------
    # PROMETHEUS SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.prometheus = {
      # Set a description that will appear in systemctl output
      # Change this if you want a different display name
      description = "Prometheus Monitoring System";

      # Control when this service starts during boot
      # Options: multi-user.target (normal), graphical.target (GUI systems)
      wantedBy = [ "multi-user.target" ];

      # Add dependencies here - services that must start before Prometheus
      # Example: after = [ "network.target" "postgresql.service" ];
      after = [ "network.target" ];

      serviceConfig = {
        # Service type determines how systemd manages the process
        # Use "simple" for processes that don't fork, "forking" if they daemonize
        Type = "simple";

        # Set which user/group runs Prometheus for security isolation
        # Change these if you need different permissions or user separation
        User = "prometheus";
        Group = "prometheus";

        # Main command - add or modify flags to customize Prometheus behavior
        # Common additions:
        # --web.external-url=https://your-domain.com/prometheus (for reverse proxy)
        # --log.level=debug (for more verbose logging)
        # --storage.tsdb.retention.size=10GB (limit storage by size instead of time)
        ExecStart = ''
          ${cfg.package}/bin/prometheus \
            --config.file=${cfg.dataDir}/prometheus.yml \
            --storage.tsdb.path=${cfg.dataDir}/data \
            --storage.tsdb.retention.time=${cfg.retention} \
            --web.listen-address=${cfg.bindIP}:${toString cfg.port} \
            --web.console.templates=${cfg.package}/etc/prometheus/consoles \
            --web.console.libraries=${cfg.package}/etc/prometheus/console_libraries
        '';

        # Define how to reload config without restarting (preserves metrics data)
        # HUP signal tells Prometheus to reload its configuration file
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

        # Control restart behavior on failure
        # Options: "no", "on-success", "on-failure", "always"
        Restart = "on-failure";

        # Adjust delay before restart attempts (increase if startup is slow)
        RestartSec = "10s";

        # ---- Security hardening - uncomment/add options as needed ----
        # Prevent privilege escalation attacks
        NoNewPrivileges = true;
        # Isolate /tmp from other services (recommended for security)
        PrivateTmp = true;
        # Filesystem protection level: "strict" (read-only), "full", or "true"
        ProtectSystem = "strict";
        # Hide /home directories from this service
        ProtectHome = true;
        # List directories that need write access
        # Add more paths if Prometheus needs to write elsewhere:
        # ReadWritePaths = [ cfg.dataDir "/var/log/prometheus" ];
        ReadWritePaths = [ cfg.dataDir ];
        # Additional security options you can enable:
        # PrivateDevices = true;  # Restrict device access
        # ProtectKernelTunables = true;  # Protect /proc and /sys
        # RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];  # Limit network protocols
      };

      # ----------------------------------------------------------------------------
      # PRE-START SCRIPT - Runs before service starts each time
      # Use this to generate configs, check dependencies, or prepare directories
      # ----------------------------------------------------------------------------
      preStart = let
        # Define your Prometheus configuration here
        # This Nix structure gets converted to prometheus.yml automatically
        # Build scrape configs dynamically based on enabled features
        baseScrapeConfigs = [
          # Self-monitoring job - always keep this to monitor Prometheus health
          {
            job_name = "prometheus";
            static_configs = [{
              targets = [ "localhost:${toString cfg.port}" ];
            }];
          }
        # Example of conditional scrape config - add more with ++ operator
        ] ++ lib.optional cfg.enableNodeExporter {
          job_name = "node";
          static_configs = [{
            targets = [ "localhost:9100" ];
            labels = {
              instance = "localhost";
              alias = config.networking.hostName;
            };
          }];
        }
        # Add your own scrape configs here:
        # ++ [{
        #   job_name = "my-app";
        #   static_configs = [{
        #     targets = [ "localhost:8080" ];
        #     labels = { environment = "production"; };
        #   }];
        # }]
        ;

        # Add maintenance scrape configs if enabled
        maintenanceScrapeConfigs = lib.optionals cfg.maintenance.enable (
          # Systemd exporter
          lib.optional cfg.maintenance.exporters.systemd {
            job_name = "systemd";
            static_configs = [{
              targets = [ "localhost:9558" ];
            }];
          }
          # SMARTCTL exporter
          ++ lib.optional cfg.maintenance.exporters.smartctl.enable {
            job_name = "smartctl";
            static_configs = [{
              targets = [ "localhost:9633" ];
            }];
          }
          # Blackbox HTTP
          ++ lib.optional (cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.httpTargets != []) {
            job_name = "blackbox-http";
            metrics_path = "/probe";
            params.module = [ "http_2xx" ];
            static_configs = [{
              targets = cfg.maintenance.exporters.blackbox.httpTargets;
            }];
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
                replacement = "localhost:9115";
                target_label = "__address__";
              }
            ];
          }
          # Blackbox ICMP
          ++ lib.optional (cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.icmpTargets != []) {
            job_name = "blackbox-icmp";
            metrics_path = "/probe";
            params.module = [ "icmp" ];
            static_configs = [{
              targets = cfg.maintenance.exporters.blackbox.icmpTargets;
            }];
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
                replacement = "localhost:9115";
                target_label = "__address__";
              }
            ];
          }
          # Blackbox SSL
          ++ lib.optional (cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.sslTargets != []) {
            job_name = "blackbox-ssl";
            metrics_path = "/probe";
            params.module = [ "http_2xx" ];
            static_configs = [{
              targets = cfg.maintenance.exporters.blackbox.sslTargets;
            }];
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
                replacement = "localhost:9115";
                target_label = "__address__";
              }
            ];
          }
        );

        prometheusConfig = {
          # Global defaults - adjust timing based on your monitoring needs
          # Shorter intervals = more data points but higher resource usage
          global = {
            scrape_interval = "15s";       # Change to 30s or 60s for less frequent scraping
            evaluation_interval = "15s";   # How often to check alerting rules
            external_labels = { monitor = "prometheus"; };  # Add labels to identify this instance
          };

          # Configure alertmanager endpoints (add your alertmanager targets here)
          alerting = {
            alertmanagers = [{
              static_configs = [{
                targets = [];  # Example: [ "alertmanager:9093" ]
              }];
            }];
          };

          # Reference the alert rules file that will be created from alerts.nix
          # The wildcard pattern allows for multiple rule files in the future
          rule_files = [ "${cfg.dataDir}/rules/*.yml" ];

          scrape_configs = baseScrapeConfigs ++ maintenanceScrapeConfigs;
        };

        # Convert Prometheus config to JSON as an intermediate format
        # Modify prometheusConfig above, not this line
        prometheusJsonFile = builtins.toFile "prometheus.json"
          (builtins.toJSON prometheusConfig);

        # Temporary file paths for YAML conversion
        prometheusYamlTmp = "${cfg.dataDir}/prometheus.yml.tmp";
        alertRulesYamlTmp = "${cfg.dataDir}/rules/alerts.yml.tmp";
      in ''
        # Convert main Prometheus config: JSON → YAML
        # Prometheus requires YAML format, but Nix→JSON→YAML avoids heredoc issues
        ${pkgs.remarshal}/bin/remarshal \
          -i ${prometheusJsonFile} \
          -o ${prometheusYamlTmp} \
          -if json \
          -of yaml

        # Install main config with specific permissions (660 = user and group read/write)
        # Adjust -m flag if you need different permissions
        install -m 660 -o prometheus -g prometheus ${prometheusYamlTmp} ${cfg.dataDir}/prometheus.yml

        # Create rules directory for alert rules
        # Add additional directories here if needed for other rule files
        mkdir -p ${cfg.dataDir}/rules

        # Convert alert rules from alerts.nix: JSON → YAML
        # This happens automatically on every service start/rebuild
        ${pkgs.remarshal}/bin/remarshal \
          -i ${alertRulesJsonFile} \
          -o ${alertRulesYamlTmp} \
          -if json \
          -of yaml

        # Install alert rules with correct ownership and permissions
        # Mode 644: owner read/write, group and others read-only
        install -m 644 -o prometheus -g prometheus ${alertRulesYamlTmp} ${cfg.dataDir}/rules/alerts.yml

        # Ensure data directory exists for TSDB storage
        # Add additional directories here if needed:
        # mkdir -p ${cfg.dataDir}/wal ${cfg.dataDir}/backups
        mkdir -p ${cfg.dataDir}/data

        # Set ownership on data directory
        # Add chown commands for any additional directories you create
        chown prometheus:prometheus ${cfg.dataDir}/data

        # Additional preStart tasks you might add:
        # - Validate config: ${cfg.package}/bin/promtool check config ${cfg.dataDir}/prometheus.yml
        # - Validate rules: ${cfg.package}/bin/promtool check rules ${cfg.dataDir}/rules/alerts.yml
        # - Download rule files from remote source
        # - Set up symbolic links to rule files
        # - Initialize databases or plugins
      '';
    };

    # ----------------------------------------------------------------------------
    # NODE EXPORTER - Enable if requested
    # ----------------------------------------------------------------------------
    systemd.services.prometheus-node-exporter = lib.mkIf cfg.enableNodeExporter {
      description = "Prometheus Node Exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "prometheus";
        Group = "prometheus";
        ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter "
          + "--web.listen-address=localhost:9100 "
          + lib.optionalString cfg.maintenance.enable
              "--collector.textfile.directory=/var/lib/node_exporter";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    # ----------------------------------------------------------------------------
    # NGINX REVERSE PROXY - Only configured if domain is set
    # ----------------------------------------------------------------------------
    services.nginx.enable = lib.mkIf (cfg.domain != null) true;

    services.nginx.virtualHosts = lib.mkIf (cfg.domain != null) {
      ${cfg.domain} = {
        forceSSL = cfg.enableSSL;
        enableACME = cfg.enableSSL;

        locations."/" = {
          proxyPass = "http://${cfg.bindIP}:${toString cfg.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Basic auth recommended for production
            # auth_basic "Prometheus";
            # auth_basic_user_file /etc/nginx/.htpasswd;
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      # Open Prometheus port if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
MAINTENANCE MONITORING USAGE
================================================================================

Enable maintenance monitoring features:
---------------------------------------
services.prometheus-custom = {
  enable = true;

  # Enable maintenance monitoring
  maintenance = {
    enable = true;

    exporters = {
      systemd = true;  # Service status monitoring

      blackbox = {
        enable = true;
        httpTargets = [ "https://example.com" ];
        icmpTargets = [ "8.8.8.8" "1.1.1.1" ];
        sslTargets = [ "https://example.com" ];
      };

      smartctl = {
        enable = true;
        devices = [ "/dev/sda" "/dev/nvme0n1" ];
      };

      backup = {
        enable = true;
        timestampFile = "/var/backups/last_timestamp";
        sizeFile = "/var/backups/last_size";
      };
    };
  };
};

This will:
  - Enable additional exporters for maintenance monitoring
  - Add maintenance alert rules from maintenance-alerts.nix
  - Auto-configure scrape jobs for all enabled exporters
  - Merge maintenance alerts with your existing alerts.nix

Your existing configuration continues to work unchanged!
*/

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.prometheus-custom = {
  enable = true;
};
# Access at: http://your-ip:9090
# Node Exporter enabled by default on localhost:9100
# Alert rules automatically loaded from alerts.nix


Full configuration with domain:
--------------------------------
services.prometheus-custom = {
  enable = true;
  port = 9090;
  bindIP = "0.0.0.0";
  dataDir = "/data/prometheus";
  retention = "30d";

  # Nginx reverse proxy
  domain = "prometheus.example.com";
  enableSSL = true;

  enableNodeExporter = true;
  openFirewall = true;
};


================================================================================
ALERT RULES
================================================================================

Alert rules are automatically imported from alerts.nix and converted to YAML.
The generated file is placed at: ${cfg.dataDir}/rules/alerts.yml

To modify alerts:
  1. Edit alerts.nix
  2. Run: sudo nixos-rebuild switch
  3. Alerts are automatically reloaded

View generated alert rules:
  cat /var/lib/prometheus2/rules/alerts.yml

Validate alert rules:
  promtool check rules /var/lib/prometheus2/rules/alerts.yml

Check active alerts in Prometheus UI:
  Navigate to: http://your-server:9090/alerts


================================================================================
ADDING MORE ALERT FILES
================================================================================

To add additional alert rule files:
  1. Create another .nix file (e.g., custom-alerts.nix) with same structure
  2. Import it in the let block:
     customAlerts = import ./custom-alerts.nix;
     customAlertsJsonFile = builtins.toFile "custom-alerts.json"
       (builtins.toJSON customAlerts);
  3. Add conversion in preStart:
     ${pkgs.remarshal}/bin/remarshal \
       -i ${customAlertsJsonFile} \
       -o ${cfg.dataDir}/rules/custom-alerts.yml.tmp \
       -if json -of yaml
     install -m 644 -o prometheus -g prometheus \
       ${cfg.dataDir}/rules/custom-alerts.yml.tmp \
       ${cfg.dataDir}/rules/custom-alerts.yml


================================================================================
INITIAL SETUP
================================================================================

1. Access Prometheus:
   - Navigate to http://your-server:9090 (or your domain)
   - No authentication by default (add nginx auth for production)

2. Verify Targets:
   - Go to Status → Targets
   - Should see 'prometheus' and 'node' targets as UP

3. Check Alerts:
   - Go to Alerts tab
   - Should see all alert rules loaded from alerts.nix
   - Initially all should be "Inactive" (green)

4. Query Metrics:
   - In the query box, try: node_cpu_seconds_total
   - Click "Execute" to see results
   - Switch to "Graph" tab for visualization

5. Add to Grafana:
   - In Grafana: Configuration → Data Sources → Add Prometheus
   - URL: http://localhost:9090 (or your Prometheus address)
   - Click "Save & Test"


================================================================================
CONFIGURATION
================================================================================

Both Prometheus configuration and alert rules are generated automatically
from Nix configuration. The YAML files are regenerated on every service start.

View generated configuration:
  cat /var/lib/prometheus2/prometheus.yml
  cat /var/lib/prometheus2/rules/alerts.yml

Configuration reference:
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/

Alerting rules reference:
  https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/

Note: Manual edits to YAML files will be overwritten on restart.
To persist changes, modify the Nix files instead (prometheus.nix or alerts.nix).


================================================================================
TROUBLESHOOTING
================================================================================

Check service status:
  sudo systemctl status prometheus

View logs:
  sudo journalctl -u prometheus -f

Reload configuration:
  sudo systemctl restart prometheus

Check if alerts loaded:
  curl 'http://localhost:9090/api/v1/rules' | jq

Validate configurations before applying:
  promtool check config /var/lib/prometheus2/prometheus.yml
  promtool check rules /var/lib/prometheus2/rules/alerts.yml

Common issues:
  - Alert rules not loading: Check logs for YAML parsing errors
  - Metrics missing: Verify node_exporter is running and scraped
  - Alerts not firing: Check expr syntax and metric availability
  - Target down: Check firewall, verify exporter is running

*/
