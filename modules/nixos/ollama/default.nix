{...}: {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
    ./ollama-cpu.nix
    ./ollama-p5000.nix
    #./open-webui.nix
  ];
}
