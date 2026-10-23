# ============================================================================
# FILE: prometheus/options.nix
# ============================================================================
{
  lib,
  pkgs,
}: {
  enable = lib.mkEnableOption "Prometheus monitoring system";

  port = lib.mkOption {
    type = lib.types.port;
    default = 9090;
    description = "Port for Prometheus to listen on";
  };

  # OPTIONAL: IP to bind to (default: 127.0.0.1 = localhost only)
  listenAddress = lib.mkOption {
    type = lib.types.str;
    default = "127.0.0.1";
    description = "IP address for ComfyUI to bind to (use 0.0.0.0 for all interfaces)";
  };

  domain = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "prometheus.example.com";
    description = "Domain name for nginx reverse proxy (optional)";
  };

  enableSSL = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable HTTPS with Let's Encrypt (requires domain)";
  };

  dataDir = lib.mkOption {
    type = lib.types.path;
    default = "/var/lib/prometheus2";
    example = "/data/prometheus";
    description = "Directory for Prometheus time-series data";
  };

  retention = lib.mkOption {
    type = lib.types.str;
    default = "15d";
    example = "30d";
    description = "How long to retain metrics data";
  };

  package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.prometheus;
    defaultText = lib.literalExpression "pkgs.prometheus";
    description = "The Prometheus package to use";
  };

  openFirewall = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Open firewall ports";
  };

  enableNodeExporter = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable Prometheus Node Exporter for system metrics";
  };

  extraScrapeConfigs = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [];
    example = [
      {
        job_name = "ntfy";
        static_configs = [{targets = ["127.0.0.1:2586"];}];
      }
    ];
    description = ''
      Additional raw Prometheus scrape_config entries, merged in verbatim
      after the base and maintenance scrape configs. Intended to be set by
      a stack module wiring this Prometheus instance to sibling services it
      should observe, not typically set by hand on a host.
    '';
  };

  alertmanagerTargets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["127.0.0.1:9093"];
    description = "Alertmanager host:port targets. Empty disables alert delivery.";
  };

  # OPTIONAL: allow opting out of the mainUser group membership
  # without coupling to a specific external option name
  extraUsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["alice"];
    description = "Extra users to add to the groups";
  };

  # Maintenance options (defined inline)
  maintenance = {
    enable = lib.mkEnableOption "maintenance monitoring exporters and alerts";

    alerts.features = {
      traefik = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Load HighHTTPErrorRate. Requires a scrape job exposing traefik_service_requests_total.";
      };
      containers = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Load ContainerRestartLoop/ContainerHighMemory. Requires cAdvisor-style container_* metrics.";
      };
      postgres = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Load PostgresReplicationLag. Requires a postgres exporter (pg_replication_lag_seconds).";
      };
    };

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
          example = ["https://example.com"];
          description = "HTTP targets to monitor";
        };
        icmpTargets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["8.8.8.8" "1.1.1.1"];
          description = "ICMP targets to ping";
        };
        sslTargets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["https://example.com"];
          description = "SSL certificate targets to monitor";
        };
        dnsTargets = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          example = ["1.1.1.1" "192.168.1.1"];
          description = "DNS servers to probe by resolving dnsQueryName. Enables DNSResolutionFailure.";
        };
        dnsQueryName = lib.mkOption {
          type = lib.types.str;
          default = "example.com";
          description = "Name resolved by the DNS probe.";
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
          example = ["/dev/sda" "/dev/nvme0n1"];
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
        jobName = lib.mkOption {
          type = lib.types.str;
          default = "backup";
          description = "Value of the job_name label on backup metrics (used in alert text).";
        };
      };
    };
  };
}
# NOTE: Maintenance options are defined inline in options.nix above
# If you wanted to split them further, you could create:
# prometheus/options/maintenance.nix and import it in options.nix

