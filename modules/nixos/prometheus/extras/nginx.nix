# ============================================================================
# FILE: prometheus/extras/nginx.nix
# ============================================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus-custom;
in
{
  enable = lib.mkIf (cfg.domain != null) true;

  virtualHosts = lib.mkIf (cfg.domain != null) {
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
        '';
      };
    };
  };
}
