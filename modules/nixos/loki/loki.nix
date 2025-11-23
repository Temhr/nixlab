{ config, lib, pkgs, ... }:

let
  cfg = config.services.loki-custom;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.loki-custom = {
      # REQUIRED: Enable the service
      enable = lib.mkEnableOption "Loki log aggregation system";

      # OPTIONAL: Port to listen on (default: 3100)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3100;
        description = "Port for Loki to listen on";
      };

      # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "IP address to bind to (use 0.0.0.0 for all interfaces)";
      };

      # OPTIONAL: Domain for nginx reverse proxy (default: null = no proxy)
      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "loki.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt (requires domain)";
      };

      # OPTIONAL: Where to store Loki data (default: /var/lib/loki)
      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/loki";
        example = "/data/loki";
        description = "Directory for Loki data storage";
      };

      # OPTIONAL: Log retention period (default: 744h = 31 days)
      retention = lib.mkOption {
        type = lib.types.str;
        default = "744h";
        example = "2160h";
        description = "How long to retain log data (in hours)";
      };

      # OPTIONAL: Loki package to use (default: pkgs.grafana-loki)
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.grafana-loki;
        defaultText = lib.literalExpression "pkgs.grafana-loki";
        description = "The Loki package to use";
      };

      # OPTIONAL: Alloy package to use (default: pkgs.grafana-alloy)
      alloyPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.grafana-alloy;
        defaultText = lib.literalExpression "pkgs.grafana-alloy";
        description = "The Grafana Alloy package to use";
      };

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Enable Alloy for local log collection (default: true)
      enableAlloy = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Grafana Alloy to collect system logs";
      };

      # Maintenance monitoring options
      maintenance = {
        enable = lib.mkEnableOption "maintenance task logging integration";

        logPath = lib.mkOption {
          type = lib.types.str;
          default = "/var/log/maintenance.log";
          description = "Path to maintenance log file";
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
      "d ${cfg.dataDir} 0750 loki loki -"
      "d ${cfg.dataDir}/chunks 0750 loki loki -"
      "d ${cfg.dataDir}/index 0750 loki loki -"
      "d ${cfg.dataDir}/wal 0750 loki loki -"
    ] ++ lib.optionals cfg.enableAlloy [
      "d /var/lib/alloy 0750 alloy alloy -"
      "d /var/lib/alloy/data 0750 alloy alloy -"
    ] ++ lib.optionals cfg.maintenance.enable [
      "f ${cfg.maintenance.logPath} 0666 root root - -"
    ];

    # ----------------------------------------------------------------------------
    # USER SETUP - Create dedicated system users
    # ----------------------------------------------------------------------------
    users.users.loki = {
      isSystemUser = true;
      group = "loki";
      home = cfg.dataDir;
      description = "Loki service user";
    };

    users.groups.loki = {};

    users.users.alloy = lib.mkIf cfg.enableAlloy {
      isSystemUser = true;
      group = "alloy";
      description = "Grafana Alloy service user";
      extraGroups = [ "systemd-journal" ];
    };

    users.groups.alloy = lib.mkIf cfg.enableAlloy {};

    users.users.temhr.extraGroups = [ "loki" "alloy" ];

    # ----------------------------------------------------------------------------
    # LOKI SERVICE - Configure the systemd service
    # ----------------------------------------------------------------------------
    systemd.services.loki = {
      description = "Loki Log Aggregation System";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = "loki";
        Group = "loki";
        ExecStart = "${cfg.package}/bin/loki --config.file=${cfg.dataDir}/loki.yaml";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
      };

      preStart = let
        lokiConfig = {
          auth_enabled = false;

          server = {
            http_listen_address = cfg.bindIP;
            http_listen_port = cfg.port;
            grpc_listen_port = 9096;
            log_level = "info";
          };

          common = {
            path_prefix = cfg.dataDir;
            storage = {
              filesystem = {
                chunks_directory = "${cfg.dataDir}/chunks";
                rules_directory = "${cfg.dataDir}/rules";
              };
            };
            replication_factor = 1;
            ring = {
              kvstore = {
                store = "inmemory";
              };
            };
          };

          query_range = {
            results_cache = {
              cache = {
                embedded_cache = {
                  enabled = true;
                  max_size_mb = 100;
                };
              };
            };
          };

          schema_config = {
            configs = [{
              from = "2023-01-01";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }];
          };

          limits_config = {
            retention_period = cfg.retention;
            max_query_series = 10000;
            max_query_lookback = "720h";
          };

          compactor = {
            working_directory = "${cfg.dataDir}/compactor";
            retention_enabled = true;
            retention_delete_delay = "2h";
            retention_delete_worker_count = 150;
            delete_request_store = "filesystem";
          };

          ingester = {
            wal = {
              enabled = true;
              dir = "${cfg.dataDir}/wal";
            };
            lifecycler = {
              address = "127.0.0.1";
              ring = {
                kvstore = {
                  store = "inmemory";
                };
                replication_factor = 1;
              };
            };
          };
        };

        jsonFile = builtins.toFile "loki.json"
          (builtins.toJSON lokiConfig);

        yamlTmp = "${cfg.dataDir}/loki.yaml.tmp";

      in ''
        ${pkgs.remarshal}/bin/remarshal \
          -i ${jsonFile} \
          -o ${yamlTmp} \
          -if json \
          -of yaml

        install -m 660 -o loki -g loki ${yamlTmp} ${cfg.dataDir}/loki.yaml

        mkdir -p ${cfg.dataDir}/data ${cfg.dataDir}/chunks ${cfg.dataDir}/wal ${cfg.dataDir}/compactor
        chown -R loki:loki ${cfg.dataDir}
      '';
    };

    # ----------------------------------------------------------------------------
    # GRAFANA ALLOY SERVICE - Enable if requested
    # ----------------------------------------------------------------------------
    systemd.services.alloy = lib.mkIf cfg.enableAlloy {
      description = "Grafana Alloy Telemetry Collector";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "loki.service" ];

      serviceConfig = {
        Type = "simple";
        User = "alloy";
        Group = "alloy";
        ExecStart = "${cfg.alloyPackage}/bin/alloy run --storage.path=/var/lib/alloy/data /var/lib/alloy/config.alloy";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/alloy" ];
      };

      preStart = let
        # Base configuration in Alloy's River configuration language
        baseAlloyConfig = ''
          // Loki client for sending logs
          loki.write "local" {
            endpoint {
              url = "http://localhost:${toString cfg.port}/loki/api/v1/push"
            }
          }

          // Collect systemd journal logs
          loki.source.journal "systemd" {
            max_age = "12h"
            labels = {
              job  = "systemd-journal",
              host = "${config.networking.hostName}",
            }

            forward_to = [loki.process.systemd.receiver]
          }

          loki.process "systemd" {
            forward_to = [loki.write.local.receiver]

            stage.static_labels {
              values = {
                job  = "systemd-journal",
                host = "${config.networking.hostName}",
              }
            }

            stage.label_keep {
              values = ["job", "host", "unit"]
            }
          }

          // Collect system log files
          local.file_match "varlogs" {
            path_targets = [{
              __address__ = "localhost",
              __path__    = "/var/log/*.log",
            }]
          }

          loki.source.file "varlogs" {
            targets    = local.file_match.varlogs.targets
            forward_to = [loki.process.varlogs.receiver]
          }

          loki.process "varlogs" {
            forward_to = [loki.write.local.receiver]

            stage.static_labels {
              values = {
                job  = "varlogs",
                host = "${config.networking.hostName}",
              }
            }
          }
        '';

        # Maintenance log configuration
        maintenanceAlloyConfig = lib.optionalString cfg.maintenance.enable ''
          // Collect maintenance logs
          local.file_match "maintenance" {
            path_targets = [{
              __address__ = "localhost",
              __path__    = "${cfg.maintenance.logPath}",
            }]
          }

          loki.source.file "maintenance" {
            targets    = local.file_match.maintenance.targets
            forward_to = [loki.process.maintenance.receiver]
          }

          loki.process "maintenance" {
            forward_to = [loki.write.local.receiver]

            // Parse JSON logs
            stage.json {
              expressions = {
                timestamp = "timestamp",
                level     = "level",
                section   = "section",
                task      = "task",
                status    = "status",
                notes     = "notes",
                user      = "user",
              }
            }

            // Extract labels
            stage.labels {
              values = {
                job     = "maintenance-log",
                host    = "${config.networking.hostName}",
                level   = "",
                section = "",
                status  = "",
                user    = "",
              }
            }

            // Parse timestamp
            stage.timestamp {
              source = "timestamp"
              format = "RFC3339"
            }
          }
        '';

        alloyConfig = baseAlloyConfig + maintenanceAlloyConfig;

        # Write config to file using writeText to avoid shell escaping issues
        configFile = pkgs.writeText "alloy-config.alloy" alloyConfig;

      in ''
        # Copy Alloy configuration
        install -m 640 -o alloy -g alloy ${configFile} /var/lib/alloy/config.alloy

        # Ensure data directory exists
        mkdir -p /var/lib/alloy/data
        chown -R alloy:alloy /var/lib/alloy
      '';
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

            # Required for Loki
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
    };

    # ----------------------------------------------------------------------------
    # FIREWALL - Open necessary ports if requested
    # ----------------------------------------------------------------------------
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      lib.optionals (cfg.domain == null) [ cfg.port ]
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );

    # ----------------------------------------------------------------------------
    # MAINTENANCE LOG HELPER SCRIPT
    # ----------------------------------------------------------------------------
    environment.systemPackages = lib.optionals cfg.maintenance.enable [
      (pkgs.writeScriptBin "maintenance-log" ''
        #!${pkgs.bash}/bin/bash
        ${builtins.readFile ./maintenance-logger.sh}
      '')
      pkgs.jq
    ];
  };
}

/*
================================================================================
GRAFANA ALLOY MIGRATION NOTES
================================================================================

What Changed:
-------------
1. Replaced Promtail with Grafana Alloy (the recommended successor)
2. Configuration language changed from YAML to River (Alloy's config language)
3. Option renamed: enablePromtail → enableAlloy
4. New option: alloyPackage to specify Alloy version
5. User/group changed from promtail → alloy

Why Migrate:
------------
- Promtail is deprecated (EOL: March 2, 2026)
- Alloy is a unified collector for logs, metrics, and traces
- Better performance and more features
- Active development and long-term support
- Native OpenTelemetry support

Migration from Old Config:
--------------------------
If you had:
  services.loki-custom.enablePromtail = true;

Now use:
  services.loki-custom.enableAlloy = true;

Everything else remains the same!


================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.loki-custom = {
  enable = true;
  enableAlloy = true;  # Changed from enablePromtail
};
# Access at: http://your-ip:3100
# Alloy enabled by default, collecting system logs


Full configuration with domain:
--------------------------------
services.loki-custom = {
  enable = true;
  port = 3100;
  bindIP = "0.0.0.0";
  dataDir = "/data/loki";
  retention = "2160h";  # 90 days

  # Nginx reverse proxy
  domain = "loki.example.com";
  enableSSL = true;

  enableAlloy = true;
  openFirewall = true;
};


With maintenance logging:
--------------------------
services.loki-custom = {
  enable = true;
  enableAlloy = true;

  maintenance = {
    enable = true;
    logPath = "/var/log/maintenance.log";
  };
};


================================================================================
INITIAL SETUP
================================================================================

1. Verify Loki is running:
   curl http://localhost:3100/ready
   # Should return "ready"

2. Check Alloy is sending logs:
   curl http://localhost:3100/loki/api/v1/label/__name__/values
   # Should show log stream labels

3. View Alloy UI (for debugging):
   http://localhost:12345
   # Shows component graph and health

4. Add to Grafana:
   - In Grafana: Configuration → Data Sources → Add Loki
   - URL: http://localhost:3100
   - Click "Save & Test"

5. Query logs in Grafana:
   - Create new dashboard
   - Add panel → Select Loki data source
   - Query: {job="systemd-journal"}
   - Or: {unit="nginx.service"}


================================================================================
ALLOY CONFIGURATION
================================================================================

Alloy uses River configuration language (similar to HCL/Terraform).

View generated configuration:
  cat /var/lib/alloy/config.alloy

Key concepts:
  - Components: Building blocks (loki.source.*, loki.write, etc.)
  - Pipelines: Components forward data to each other
  - Labels: Metadata attached to log streams

River syntax example:
  loki.source.file "mylogs" {
    targets    = [{ __path__ = "/var/log/*.log" }]
    forward_to = [loki.write.local.receiver]
  }

Documentation:
  https://grafana.com/docs/alloy/latest/


================================================================================
ALLOY COMPONENTS IN THIS CONFIG
================================================================================

1. loki.write "local"
   - Sends logs to Loki
   - Endpoint: http://localhost:3100/loki/api/v1/push

2. loki.source.journal "systemd"
   - Collects systemd journal logs
   - Adds labels: job=systemd-journal, host=<hostname>
   - Relabels: __journal__systemd_unit → unit

3. local.file_match "varlogs"
   - Discovers log files matching /var/log/*.log
   - Dynamic file discovery

4. loki.source.file "varlogs"
   - Tails discovered log files
   - Sends to processing pipeline

5. loki.process "varlogs"
   - Adds static labels
   - Forwards to Loki writer

6. loki.source.file "maintenance" (if enabled)
   - Tails maintenance log file
   - Parses JSON logs
   - Extracts labels from JSON fields


================================================================================
LOGQL QUERIES (Same as Before)
================================================================================

Basic queries:
  {job="systemd-journal"}                    # All journal logs
  {unit="nginx.service"}                     # Nginx logs
  {job="varlogs"}                            # /var/log/*.log files
  {job="maintenance-log"}                    # Maintenance logs

Filter by content:
  {job="systemd-journal"} |= "error"
  {job="systemd-journal"} != "debug"
  {job="systemd-journal"} |~ "error|failed"

Maintenance log queries:
  {job="maintenance-log"}
  {job="maintenance-log", section="I.1"}
  {job="maintenance-log", status="completed"}
  {job="maintenance-log"} | json | status="failed"


================================================================================
TROUBLESHOOTING
================================================================================

Check Alloy status:
  sudo systemctl status alloy

View Alloy logs:
  sudo journalctl -u alloy -f

Alloy debug UI:
  http://localhost:12345
  - View component graph
  - Check component health
  - See pipeline data flow

Check Alloy configuration syntax:
  alloy fmt --write /var/lib/alloy/config.alloy

Test Loki API:
  curl http://localhost:3100/ready
  curl http://localhost:3100/metrics

Query logs via API:
  curl -G -s "http://localhost:3100/loki/api/v1/query" \
    --data-urlencode 'query={job="systemd-journal"}' \
    --data-urlencode 'limit=10'

Common issues:
  - No logs appearing: Check Alloy is running and configuration is valid
  - Permission denied: Ensure alloy user in systemd-journal group
  - Component errors: Check debug UI at localhost:12345
  - Configuration syntax errors: Use 'alloy fmt' to validate


================================================================================
MIGRATING FROM PROMTAIL
================================================================================

If you have custom Promtail configs, use the converter:

  # Install Alloy
  nix-shell -p grafana-alloy

  # Convert Promtail config
  alloy convert --source-format=promtail \
    --output=config.alloy \
    promtail.yaml

  # Review the generated config.alloy
  # Integrate relevant parts into this module's alloyConfig

Key differences:
  - Promtail: YAML configuration
  - Alloy: River configuration (HCL-like)
  - Promtail: /var/lib/promtail/positions.yaml
  - Alloy: /var/lib/alloy/data/positions/

Metrics changes:
  - Promtail metrics: promtail_*
  - Alloy metrics: alloy_* and loki_source_*


================================================================================
ADVANCED ALLOY FEATURES
================================================================================

Alloy supports many more features not in this basic config:

1. Multiple outputs:
   - Send logs to multiple Loki instances
   - Send to Grafana Cloud
   - Export to other systems

2. Advanced processing:
   - Regex extraction
   - Multiline log parsing
   - Log sampling/filtering
   - Label manipulation

3. Service discovery:
   - Kubernetes pods
   - Docker containers
   - Consul services
   - File-based discovery

4. Metrics collection:
   - Prometheus scraping
   - OTLP metrics
   - Push metrics

5. Traces collection:
   - OTLP traces
   - Zipkin
   - Jaeger

6. Clustering:
   - Distribute workload across multiple Alloy instances
   - High availability setup

See documentation for advanced configurations:
  https://grafana.com/docs/alloy/latest/reference/components/


================================================================================
SECURITY BEST PRACTICES
================================================================================

1. Use nginx reverse proxy with authentication
2. Restrict access with firewall rules
3. Enable HTTPS (set enableSSL = true with domain)
4. Limit Alloy user permissions
5. Regularly update Alloy package
6. Monitor Alloy resource usage
7. Secure log file permissions
8. Use TLS for remote Alloy instances
9. Backup configuration files

*/
