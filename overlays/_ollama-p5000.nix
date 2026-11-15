# Ollama (CUDA 12.9, Pascal / sm_61) overlay
# CUDA 13 dropped Pascal, so ollama-cuda must be built against a CUDA 12.x set.
{
  nixpkgs-ollama,
  nixpkgs-open-webui,
  nixpkgs-stable,
  system,
}: _: _: let
  pinnedPkgs = import nixpkgs-ollama {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = true;
  };

  webuiPkgs = import nixpkgs-open-webui {
    inherit system;
    config.allowUnfree = true;
  };

  stablePkgs = import nixpkgs-stable {
    inherit system;
    config.allowUnfree = true;
  };

  # 12.9 is the last CUDA release that can still target Pascal.
  cuda12 = pinnedPkgs.cudaPackages_12_9 or pinnedPkgs.cudaPackages_12;
in {
  ollama-cuda-p5000 =
    (pinnedPkgs.ollama-cuda.override {
      cudaPackages = cuda12;
      cudaArches = ["sm_61"]; # "sm_75" "sm_80" "sm_86" "sm_89" "sm_90"
    }).overrideAttrs (old: {
      pname = "ollama-cuda-p5000";
      name = "ollama-cuda-p5000-${old.version}";
      # If the Go vendor step fails with a hash mismatch, paste the "got:" hash here.
      vendorHash = "sha256-1mzJrZUHH2ouP6I+LVojHbft7No5AumqKZVq0I/Ubsg=";
    });

  ollama = stablePkgs.ollama;
  open-webui = webuiPkgs.open-webui;
}
