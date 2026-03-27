{
  config,
  lib,
  ...
}: {
  # Only activate if any module has turned on nginx
  config = lib.mkIf config.services.nginx.enable {
    services.nginx = {
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };
  };
}
