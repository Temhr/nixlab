# Single source of truth for: which config option enables each service key,
# and which display group it belongs to. Both services.nix and settings.nix
# import this instead of maintaining their own copies.
{config}: {
  enabled = {
    "ollama-cpu" = config.services.ollama-stack.acceleration or null == "cpu";
    "ollama-gpu" = config.services.ollama-stack.acceleration or null == "cuda-p5000";
    "comfyui" = config.services.comfyui-p5000.enable or false;
    "hermes" = config.services.nixlab-hermes.enable or false;
    "bookstack" = config.services.bookstack-nixlab.enable or false;
    "wikijs" = config.services.wikijs-custom.enable or false;
    "zola" = config.services.zola-nixlab.enable or false;
    "alertmanager" = config.services.alertmanager-nixlab.enable or false;
    "grafana" = config.services.grafana-nixlab.enable or false;
    "ntfy" = config.services.ntfy-nixlab.enable or false; # confirm exact name
    "prometheus" = config.services.prometheus-nixlab.enable or false;
    "loki" = config.services.loki-nixlab.enable or false;
    "home-assistant" = config.services.homeassistant-custom.enable or false;
    "node-red" = config.services.nodered-service.enable or false;
    "syncthing" = config.services.syncthing-nixlab.enable or false;
    "gotosocial" = config.services.gotosocial-nixlab.enable or false; # confirm exact name
    "glance" = config.services.glance-nixlab.enable or false;
  };

  groups = {
    "ollama-cpu" = "AI & Inference";
    "ollama-gpu" = "AI & Inference";
    "comfyui" = "AI & Inference";
    "hermes" = "AI & Inference";
    "bookstack" = "Knowledge & Docs";
    "wikijs" = "Knowledge & Docs";
    "zola" = "Knowledge & Docs";
    "alertmanager" = "Monitoring & Logs";
    "grafana" = "Monitoring & Logs";
    "ntfy" = "Monitoring & Logs";
    "prometheus" = "Monitoring & Logs";
    "loki" = "Monitoring & Logs";
    "home-assistant" = "Home & Automation";
    "node-red" = "Home & Automation";
    "syncthing" = "Sync and Storage";
    "gotosocial" = "Social & Feeds";
    "glance" = "Social & Feeds";
  };

  # Ports for the services that have one; used by the monitoring stack to probe them.
  endpoints = {
    "comfyui" = {port = config.services.comfyui-p5000.port or 8188;};
    "ollama-cpu" = {port = config.services.ollama-stack.ollamaPort or 11434;};
    "ollama-gpu" = {port = config.services.ollama-stack.ollamaPort or 11434;};
    "hermes" = {port = config.services.nixlab-hermes.dashboard.port or 9119;};
    "bookstack" = {port = config.services.bookstack-nixlab.port or 6875;};
    "wikijs" = {port = config.services.wikijs-custom.port or 3001;};
    "zola" = {port = config.services.zola-nixlab.port or 3003;};
    "home-assistant" = {port = config.services.homeassistant-custom.port or 8123;};
    "node-red" = {port = config.services.nodered-service.port or 1880;};
    "syncthing" = {port = config.services.syncthing-nixlab.guiPort or 8384;};
    "glance" = {port = config.services.glance-nixlab.port or 3004;};
  };
}
