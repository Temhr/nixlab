{ config, pkgs, ... }:

{
 systemd.services.wiki-js = {
   requires = [ "postgresql.service" ];
   after    = [ "postgresql.service" ];
 };
 services.wiki-js = {
   enable = true;
   settings.db = {
     db  = "wiki-js";
     host = "/run/postgresql";
     type = "postgres";
     user = "wiki-js";
   };
 };
 services.postgresql = {
   enable = true;
   ensureDatabases = [ "wiki-js" ];
   ensureUsers = [{
     name = "wiki-js";
     ensureDBOwnership = true;
   }];
 };

/*
  # Optional: Set up nginx reverse proxy
  services.nginx = {
    enable = true;
    virtualHosts."wiki.yourdomain.com" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
      };
      # Optional: Enable HTTPS with Let's Encrypt
      # forceSSL = true;
      # enableACME = true;
    };
  };
*/

  # Open firewall for HTTP/HTTPS if using nginx
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
