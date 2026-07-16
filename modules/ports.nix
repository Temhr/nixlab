# Port Service Manifest
#
# Port precedence (highest to lowest):
#   1. Host config files (hosts/<name>.nix) — plain assignment, e.g.
#        services.glance-nixlab.port = 3005;
#      Always wins; do NOT use lib.mkDefault here or it will tie with
#      this file's own mkDefault and cause an eval error.
#   2. This file (ports.nix / ports-X modules) — lib.mkDefault, e.g.
#        services.glance-nixlab.port = lib.mkDefault 3004;
#      The fleet-wide sensible default for hosts that don't override.
#   3. Each service module's own `options.services.X.port` default —
#      lowest priority, only takes effect if this file isn't imported
#      for that service at all (rare; a safety net, not meant to be
#      kept in sync with #2 by hand).
{...}: {
  flake.nixosModules.systm--ports-nodered = {lib, ...}: {
    services.nodered-service.port = lib.mkDefault 1880;
  };
  flake.nixosModules.systm--ports-ntfy = {lib, ...}: {
    services.ntfy-nixlab.port = lib.mkDefault 2586;
  };
  flake.nixosModules.systm--ports-homepage = {lib, ...}: {
    services.homepage-nixlab.port = lib.mkDefault 3000;
  };
  flake.nixosModules.systm--ports-wikijs = {lib, ...}: {
    services.wikijs-custom.port = lib.mkDefault 3001;
  };
  flake.nixosModules.systm--ports-zola = {lib, ...}: {
    services.zola-nixlab.port = lib.mkDefault 3003;
  };
  flake.nixosModules.systm--ports-glance = {lib, ...}: {
    services.glance-nixlab.port = lib.mkDefault 3004;
  };
  flake.nixosModules.systm--ports-llm = {lib, ...}: {
    services.ollama-stack.webuiPort = lib.mkDefault 3007;
    services.ollama-stack.ollamaPort = lib.mkDefault 11434;
  };
  flake.nixosModules.systm--ports-loki = {lib, ...}: {
    services.loki-nixlab.port = lib.mkDefault 3100;
    services.loki-nixlab.grpcPort = lib.mkDefault 9096;
  };
  flake.nixosModules.systm--ports-grafana = {lib, ...}: {
    services.grafana-nixlab.port = lib.mkDefault 3101;
  };
  flake.nixosModules.systm--ports-bookstack = {lib, ...}: {
    services.bookstack-nixlab.port = lib.mkDefault 6875;
  };
  flake.nixosModules.systm--ports-homeassistant = {lib, ...}: {
    services.homeassistant-custom.port = lib.mkDefault 8123;
  };
  flake.nixosModules.systm--ports-comfyui = {lib, ...}: {
    services.comfyui-p5000.port = lib.mkDefault 8188;
  };
  flake.nixosModules.systm--ports-syncthing = {lib, ...}: {
    services.syncthing-nixlab.guiPort = lib.mkDefault 8384;
  };
  flake.nixosModules.systm--ports-prometheus = {lib, ...}: {
    services.prometheus-nixlab.port = lib.mkDefault 9090;
  };
  flake.nixosModules.systm--ports-alertmanager = {lib, ...}: {
    services.alertmanager-nixlab.port = lib.mkDefault 9093;
  };
}
