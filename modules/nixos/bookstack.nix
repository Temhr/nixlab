{ config, lib, pkgs, ... }:

let
  cfg = config.services.bookstack;
in
{
  options = {
    services.bookstack = {
      enable = lib.mkEnableOption "BookStack service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3002;
        description = "Port for BookStack to listen on";
      };

      bindIP = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "IP address to bind to";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        example = "wiki.example.com";
        description = "Domain name for BookStack (required)";
      };

      enableSSL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable HTTPS with Let's Encrypt";
      };

      dataDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bookstack";
        example = "/data/bookstack";
        description = "Directory for BookStack data";
      };

      appKeyFile = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/bookstack-appkey";
        description = "Path to file containing the app key";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open firewall ports for HTTP/HTTPS";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure app key file exists
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 bookstack bookstack -"
      "f ${cfg.appKeyFile} 0600 bookstack bookstack -"
    ];

    # Use the built-in BookStack module
    services.bookstack = {
      enable = true;
      hostname = cfg.domain;
      appKeyFile = cfg.appKeyFile;

      database.createLocally = true;

      nginx = {
        enableACME = cfg.enableSSL;
        forceSSL = cfg.enableSSL;
        listen = [
          { addr = cfg.bindIP; port = cfg.port; ssl = false; }
        ];
      };
    };

    # Firewall configuration
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      [ cfg.port ] ++ lib.optionals cfg.enableSSL [ 80 443 3002 ]
    );
  };
}

/*
Usage example:

services.bookstack = {
  enable = true;
  domain = "wiki.example.com";
  port = 3002;
  bindIP = "0.0.0.0";
  enableSSL = true;
  dataDir = "/data/bookstack";
  openFirewall = true;
};

# First-time setup:
# 1. Generate app key:
#    echo "base64:$(openssl rand -base64 32)" | sudo tee /var/lib/bookstack-appkey
#    sudo chown bookstack:bookstack /var/lib/bookstack-appkey
#    sudo chmod 600 /var/lib/bookstack-appkey
#
# 2. Default credentials:
#    Email: admin@admin.com
#    Password: password
#    (Change immediately after first login!)
*/
