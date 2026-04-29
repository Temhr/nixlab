{
  nixpkgs-ollama,
  nixpkgs-stable,
  system,
}: _: prev: let
  # CUDA packages from pinned nixpkgs-ollama
  cudaPkgs = import nixpkgs-ollama {
    inherit system;
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
      cudaSupport = true;
      cudaCapabilities = ["6.1"];
      cudaForwardCompat = false; # Disable forward compat to skip cuda_compat
    };
  };

  # CPU packages from stable
  stablePkgs = import nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };
in {
  # CUDA-optimized Ollama for P5000
  ollama-cuda-p5000 =
    (cudaPkgs.ollama-cuda.override {
      cudaArches = ["sm_61"]; # ONLY P5000
      # Also try disabling cuda_compat at the package level
      cudaPackages =
        cudaPkgs.cudaPackages
        // {
          cuda_compat = null;
        };
    }).overrideAttrs (old: {
      pname = "ollama-cuda-p5000";
      name = "ollama-cuda-p5000-${old.version}";
      vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
    });

  # CPU-only Ollama from stable
  ollama-cpu = stablePkgs.ollama;

  # Open WebUI from stable for CPU, from pinned for CUDA
  open-webui-stable = stablePkgs.open-webui;
  open-webui-cuda = cudaPkgs.open-webui;
}
