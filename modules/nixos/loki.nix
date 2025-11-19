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

      # OPTIONAL: Port to listen on (default: 3101)
      port = lib.mkOption {
        type = lib.types.port;
        default = 3101;
        description = "Port for Loki to listen on";
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
        example = "loki.example.com";
        description = "Domain name for nginx reverse proxy (optional)";
      };

      # OPTIONAL: Enable SSL/HTTPS with Let's Encrypt (default: false)
      # Only works if domain is set
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

      # OPTIONAL: Auto-open firewall ports (default: true)
      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports";
      };

      # OPTIONAL: Enable Promtail for local log collection (default: true)
      enablePromtail = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Promtail to collect system logs";
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
    ] ++ lib.optionals cfg.enablePromtail [
      "d /var/lib/promtail 0750 promtail promtail -"
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

    users.users.temhr.extraGroups = [ "loki" ];

    users.users.promtail = lib.mkIf cfg.enablePromtail {
      isSystemUser = true;
      group = "promtail";
      description = "Promtail service user";
      extraGroups = [ "systemd-journal" ];
    };

    users.groups.promtail = lib.mkIf cfg.enablePromtail {};

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

      # Ensure config file exists with proper permissions
      preStart = ''
        # Create default config if it doesn't exist
        if [ ! -f ${cfg.dataDir}/loki.yaml ]; then
          cat > ${cfg.dataDir}/loki.yaml << EOF
# Loki Configuration
# See: https://grafana.com/docs/loki/latest/configuration/

auth_enabled: false

server:
  http_listen_address: ${cfg.bindIP}
  http_listen_port: ${toString cfg.port}
  grpc_listen_port: 9096
  log_level: info

common:
  path_prefix: ${cfg.dataDir}
  storage:
    filesystem:
      chunks_directory: ${cfg.dataDir}/chunks
      rules_directory: ${cfg.dataDir}/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2023-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: ${cfg.retention}
  max_query_series: 10000
  max_query_lookback: 720h

compactor:
  working_directory: ${cfg.dataDir}/compactor
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150

ingester:
  wal:
    enabled: true
    dir: ${cfg.dataDir}/wal
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
EOF
          chown loki:loki ${cfg.dataDir}/loki.yaml
          chmod 660 ${cfg.dataDir}/loki.yaml
        fi
      '';
    };

    # ----------------------------------------------------------------------------
    # PROMTAIL SERVICE - Enable if requested
    # ----------------------------------------------------------------------------
    systemd.services.promtail = lib.mkIf cfg.enablePromtail {
      description = "Promtail Log Collector";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "loki.service" ];

      serviceConfig = {
        Type = "simple";
        User = "promtail";
        Group = "promtail";
        ExecStart = "${cfg.package}/bin/promtail --config.file=/var/lib/promtail/promtail.yaml";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/promtail" ];
      };

      preStart = ''
        # Create default Promtail config if it doesn't exist
        if [ ! -f /var/lib/promtail/promtail.yaml ]; then
          cat > /var/lib/promtail/promtail.yaml << EOF
# Promtail Configuration
# See: https://grafana.com/docs/loki/latest/send-data/promtail/

server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://localhost:${toString cfg.port}/loki/api/v1/push

scrape_configs:
  # Collect systemd journal logs
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
        host: \$(hostname)
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'

  # Collect logs from /var/log
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: \$(hostname)
          __path__: /var/log/*.log
EOF
          chown promtail:promtail /var/lib/promtail/promtail.yaml
          chmod 640 /var/lib/promtail/promtail.yaml
        fi
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
      # Open Loki port if not using reverse proxy
      lib.optionals (cfg.domain == null) [ cfg.port ]
      # Open HTTP/HTTPS if using reverse proxy
      ++ lib.optionals (cfg.domain != null) [ 80 443 ]
    );
  };
}

/*
================================================================================
USAGE EXAMPLE
================================================================================

Minimal configuration:
----------------------
services.loki-custom = {
  enable = true;
};
# Access at: http://your-ip:3101
# Promtail enabled by default, collecting system logs


Full configuration with domain:
--------------------------------
services.loki-custom = {
  enable = true;
  port = 3101;
  bindIP = "0.0.0.0";
  dataDir = "/data/loki";
  retention = "2160h";  # 90 days

  # Nginx reverse proxy
  domain = "loki.example.com";
  enableSSL = true;

  enablePromtail = true;
  openFirewall = true;
};


================================================================================
INITIAL SETUP
================================================================================

1. Verify Loki is running:
   curl http://localhost:3101/ready
   # Should return "ready"

2. Check Promtail is sending logs:
   curl http://localhost:3101/loki/api/v1/label/__name__/values
   # Should show log stream labels

3. Add to Grafana:
   - In Grafana: Configuration → Data Sources → Add Loki
   - URL: http://localhost:3101
   - Click "Save & Test"

4. Query logs in Grafana:
   - Create new dashboard
   - Add panel → Select Loki data source
   - Query: {job="systemd-journal"}
   - Or: {unit="nginx.service"}


================================================================================
CONFIGURATION
================================================================================

Loki configuration is in loki.yaml in dataDir.
A default config is created automatically on first run.

Edit Loki configuration:
  sudo nano /var/lib/loki/loki.yaml
  sudo systemctl restart loki

Edit Promtail configuration:
  sudo nano /var/lib/promtail/promtail.yaml
  sudo systemctl restart promtail

Validate Loki config:
  ${pkgs.grafana-loki}/bin/loki --config.file=/var/lib/loki/loki.yaml --verify-config

Configuration reference:
  https://grafana.com/docs/loki/latest/configuration/


================================================================================
LOGQL QUERIES
================================================================================

LogQL is Loki's query language (similar to PromQL).

Basic queries:
  {job="systemd-journal"}                    # All journal logs
  {unit="nginx.service"}                     # Nginx logs
  {job="varlogs", filename="/var/log/syslog"} # Specific file

Filter by content:
  {job="systemd-journal"} |= "error"         # Contains "error"
  {job="systemd-journal"} != "debug"         # Doesn't contain "debug"
  {job="systemd-journal"} |~ "error|failed"  # Regex match

Parsing and filtering:
  {job="systemd-journal"} | json             # Parse JSON logs
  {job="systemd-journal"} | logfmt           # Parse logfmt logs
  {job="nginx"} | pattern "<ip> - - <_> \"<method> <uri> <_>\" <status>" | status >= 400

Aggregations:
  count_over_time({job="systemd-journal"}[5m])  # Count logs
  rate({job="systemd-journal"}[5m])             # Logs per second
  sum by (unit) (count_over_time({job="systemd-journal"}[1h]))  # Count by unit


================================================================================
ADDING LOG SOURCES
================================================================================

To collect logs from other sources, edit Promtail config:

Example - Application logs:
  - job_name: myapp
    static_configs:
      - targets:
          - localhost
        labels:
          job: myapp
          __path__: /var/log/myapp/*.log

Example - Docker containers:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: 'container'

Example - Custom format:
  - job_name: custom
    static_configs:
      - targets:
          - localhost
        labels:
          job: custom
          __path__: /var/log/custom/*.log
    pipeline_stages:
      - regex:
          expression: '(?P<timestamp>\\S+) (?P<level>\\S+) (?P<message>.*)'
      - labels:
          level:
      - timestamp:
          source: timestamp
          format: RFC3339


================================================================================
SENDING LOGS FROM APPLICATIONS
================================================================================

Applications can send logs directly to Loki via HTTP:

Using curl:
  curl -X POST http://localhost:3101/loki/api/v1/push \
    -H "Content-Type: application/json" \
    -d '{
      "streams": [
        {
          "stream": {"job": "myapp", "level": "info"},
          "values": [
            ["'$(date +%s)000000000'", "Application started"]
          ]
        }
      ]
    }'

Using LogCLI:
  ${pkgs.grafana-loki}/bin/logcli --addr=http://localhost:3101 \
    --labels='job=test' \
    push "Test log message"


================================================================================
TROUBLESHOOTING
================================================================================

Check Loki status:
  sudo systemctl status loki

Check Promtail status:
  sudo systemctl status promtail

View Loki logs:
  sudo journalctl -u loki -f

View Promtail logs:
  sudo journalctl -u promtail -f

Test Loki API:
  curl http://localhost:3101/ready
  curl http://localhost:3101/metrics

Query logs via API:
  curl -G -s "http://localhost:3101/loki/api/v1/query" \
    --data-urlencode 'query={job="systemd-journal"}' \
    --data-urlencode 'limit=10'

Check Promtail targets:
  curl http://localhost:9080/targets

Common issues:
  - No logs appearing: Check Promtail is running and configured
  - Permission denied: Ensure promtail user in systemd-journal group
  - Out of disk space: Reduce retention period
  - Query timeout: Reduce time range or add more filters
  - Labels not appearing: Check relabel_configs in Promtail


================================================================================
RETENTION AND STORAGE
================================================================================

Default retention: 744 hours (31 days)
Adjust with: retention = "2160h";  # 90 days

Storage locations:
  - Chunks: ${cfg.dataDir}/chunks
  - Index: ${cfg.dataDir}/index
  - WAL: ${cfg.dataDir}/wal

Estimate storage needs:
  - Highly variable based on log volume
  - Typical: 1-10 GB per million log lines
  - Monitor with: du -sh ${cfg.dataDir}/*

Compaction:
  - Loki automatically compacts old data
  - Configurable via compactor settings
  - Old data deleted based on retention_period


================================================================================
SECURITY BEST PRACTICES
================================================================================

1. Use nginx reverse proxy with authentication
2. Restrict access with firewall rules
3. Enable HTTPS (set enableSSL = true with domain)
4. Use read-only access in Grafana
5. Regularly update Loki package
6. Monitor Loki resource usage
7. Secure Promtail on remote hosts (use TLS)
8. Backup configuration files

*/
