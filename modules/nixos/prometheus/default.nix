# ============================================================================
# FILE STRUCTURE for modular approach:
# ============================================================================
# prometheus/
# ├── default.nix              # Main module (imports everything)
# ├── options.nix              # All module options (includes maintenance)
# ├── config.nix               # Main config assembly
# ├── scrape-configs.nix       # Scrape job builders
# ├── exporters/
# │   ├── node.nix             # Node exporter config
# │   └── maintenance.nix      # All maintenance exporters
# ├── services/
# │   └── prometheus.nix       # Main prometheus service definition
# └── extras/
#     └── nginx.nix            # Nginx reverse proxy config

# ============================================================================
# FILE: prometheus/default.nix (main entry point)
# ============================================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.services.prometheus-custom;

  # Import all submodules - pass pkgs to options
  options = import ./options.nix { inherit lib pkgs; };
  prometheusConfig = import ./config.nix { inherit config lib pkgs; };
in
{
  # Import options from separate file
  options.services.prometheus-custom = options;

  # Import configuration from separate file
  config = lib.mkIf cfg.enable prometheusConfig;
}

# ============================================================================
# USAGE in configuration.nix:
# ============================================================================
# Instead of:
#   imports = [ ./prometheus.nix ];
#
# Use:
#   imports = [ ./prometheus ];  # imports prometheus/default.nix
#
# Configuration stays the same:
#   services.prometheus-custom = {
#     enable = true;
#     # ... options
#   };
