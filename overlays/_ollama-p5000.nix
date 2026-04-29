{
  nixpkgs-ollama,
  nixpkgs-stable,
  system,
}: _: prev: let
  # CPU packages from stable
  stablePkgs = import nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;

  };

  # Import JUST for getting ollama source/version, use prev's CUDA packages
  ollamaPkgs = import nixpkgs-ollama {
    inherit system;
    config.allowUnfree = true;

  };
in {
  # Build Ollama using YOUR nixpkgs CUDA packages (which work)
  ollama-cuda-p5000 = (prev.ollama-cuda.override {
    cudaArches = ["sm_61"];
  }).overrideAttrs (old: {
    pname = "ollama-cuda-p5000";
    name = "ollama-cuda-p5000-${old.version}";
    # You may need to update this hash if the version changed
    # vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
  });

  # CPU-only Ollama from stable
  ollama-cpu = stablePkgs.ollama;

  # Use Open WebUI from stable/your existing nixpkgs
  open-webui-stable = stablePkgs.open-webui;
  open-webui-cuda = prev.open-webui;  # Your already-built PyTorch!
}
