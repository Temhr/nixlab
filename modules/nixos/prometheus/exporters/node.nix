# ============================================================================
# FILE: prometheus/exporters/node.nix
# ============================================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus-custom;
in
{
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
}
