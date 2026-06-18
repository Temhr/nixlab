{...}: {
  flake.nixosModules.systm--ports-core = {lib, ...}: {
    services.homepage-nixlab.port = lib.mkDefault 3000;
    services.loki-nixlab.port = lib.mkDefault 3100;
    services.loki-nixlab.grpcPort = lib.mkDefault 9096;
    services.grafana-nixlab.port = lib.mkDefault 3101;
    services.prometheus-nixlab.port = lib.mkDefault 9090;
  };
  flake.nixosModules.systm--ports-llm = {lib, ...}: {
    services.ollama-stack.ollamaPort = lib.mkDefault 11434;
    services.ollama-stack.webuiPort = lib.mkDefault 3007;
  };
  flake.nixosModules.systm--ports-comfyui = {lib, ...}: {
    services.comfyui-p5000.port = lib.mkDefault 8188;
  };
  flake.nixosModules.systm--ports-syncthing = {lib, ...}: {
    services.syncthing-nixlab.guiPort = lib.mkDefault 8384;
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
  flake.nixosModules.systm--ports-homeassistant = {lib, ...}: {
    services.homeassistant-custom.port = lib.mkDefault 8123;
  };
  flake.nixosModules.systm--ports-nodered = {lib, ...}: {
    services.nodered-service.port = lib.mkDefault 1880;
  };
  flake.nixosModules.systm--ports-bookstack = {lib, ...}: {
    services.bookstack-nixlab.port = lib.mkDefault 6875;
  };
}
