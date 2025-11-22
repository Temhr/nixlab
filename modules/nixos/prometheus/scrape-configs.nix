# ============================================================================
# FILE: prometheus/scrape-configs.nix
# ============================================================================
{ config, lib }:

let
  cfg = config.services.prometheus-custom;

  # Helper for blackbox exporter jobs
  mkBlackboxJob = jobName: module: targets: {
    job_name = jobName;
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
        replacement = "localhost:9115";
        target_label = "__address__";
      }
    ];
  };

  # Base scrape configs
  baseConfigs = [
    {
      job_name = "prometheus";
      static_configs = [{
        targets = [ "localhost:${toString cfg.port}" ];
      }];
    }
  ] ++ lib.optional cfg.enableNodeExporter {
    job_name = "node";
    static_configs = [{
      targets = [ "localhost:9100" ];
      labels = {
        instance = "localhost";
        alias = config.networking.hostName;
      };
    }];
  };

  # Maintenance scrape configs
  maintenanceConfigs = lib.optionals cfg.maintenance.enable (
    lib.optional cfg.maintenance.exporters.systemd {
      job_name = "systemd";
      static_configs = [{ targets = [ "localhost:9558" ]; }];
    }
    ++ lib.optional cfg.maintenance.exporters.smartctl.enable {
      job_name = "smartctl";
      static_configs = [{ targets = [ "localhost:9633" ]; }];
    }
    ++ lib.optional (cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.httpTargets != [])
      (mkBlackboxJob "blackbox-http" "http_2xx" cfg.maintenance.exporters.blackbox.httpTargets)
    ++ lib.optional (cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.icmpTargets != [])
      (mkBlackboxJob "blackbox-icmp" "icmp" cfg.maintenance.exporters.blackbox.icmpTargets)
    ++ lib.optional (cfg.maintenance.exporters.blackbox.enable && cfg.maintenance.exporters.blackbox.sslTargets != [])
      (mkBlackboxJob "blackbox-ssl" "http_2xx" cfg.maintenance.exporters.blackbox.sslTargets)
  );
in
{
  # Export the configs
  base = baseConfigs;
  maintenance = maintenanceConfigs;
  all = baseConfigs ++ maintenanceConfigs;

  # Helper function (can be used by services/prometheus.nix)
  inherit mkBlackboxJob;
}
