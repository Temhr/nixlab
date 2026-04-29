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

  # For CUDA: Use a minimal import just for Ollama, disable problematic packages
  ollamaPkgs = import nixpkgs-ollama {
    inherit system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = ["6.1"];
      cudaForwardCompat = false;  # Disable the broken cuda_compat
    };
  };
in {
  # CUDA-optimized Ollama for P5000 - built from ollamaPkgs
  ollama-cuda-p5000 = (ollamaPkgs.ollama-cuda.override {
    cudaArches = ["sm_61"];
    # Use CUDA packages from prev (your existing nixpkgs) instead of ollamaPkgs
    # This avoids the cuda_compat issue
    inherit (prev.cudaPackages) cudatoolkit;
  }).overrideAttrs (old: {
    pname = "ollama-cuda-p5000";
    name = "ollama-cuda-p5000-${old.version}";
    vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
  });

  # CPU-only Ollama from stable
  ollama-cpu = stablePkgs.ollama;

  # Use Open WebUI from your existing nixpkgs (prev) to avoid CUDA issues
  # It will use the already-compiled PyTorch from your 33-hour build
  open-webui-stable = stablePkgs.open-webui;
  open-webui-cuda = prev.open-webui;  # Use your existing nixpkgs, not ollamaPkgs
}
