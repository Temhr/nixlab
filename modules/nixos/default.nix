{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./comfyui
    ./grafana
    ./homepage
    ./loki
    ./ollama
    ./prometheus
    ./bookstack.nix
    ./glance.nix
    ./gotosocial.nix
    ./home-assistant.nix
    ./node-red.nix
    ./syncthing.nix
    ./waydroid.nix
    ./wiki-js.nix
    ./zola.nix
  ];
}
