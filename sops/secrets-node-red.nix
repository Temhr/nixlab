{self, ...}: {
  flake.nixosModules.nsops--node-red = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.nodered-service;
  in {
    sops.secrets.NODE_RED_CREDENTIAL_SECRET = lib.mkIf cfg.enable {
      sopsFile = self + /secrets/node-red.yaml;
      owner = "node-red";
      group = "node-red";
      mode = "0440";
    };

    # Wire the secret to the service
    services.nodered-service = lib.mkIf cfg.enable {
      credentialSecretFile = config.sops.secrets.NODE_RED_CREDENTIAL_SECRET.path;
    };
  };
}
