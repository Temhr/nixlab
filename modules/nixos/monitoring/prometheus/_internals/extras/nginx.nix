# ============================================================================
# FILE: prometheus/extras/nginx.nix
# ============================================================================
{
  config,
  lib,
  nixlabLib,
}: let
  cfg = config.services.prometheus-nixlab;
in {
  enable = lib.mkIf (cfg.domain != null) true;
  virtualHosts = nixlabLib.mkNginxVirtualHost {
    inherit (cfg) domain listenAddress port enableSSL;
  };
}
