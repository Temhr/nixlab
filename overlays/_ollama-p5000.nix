{
  nixpkgs-ollama,
  system,
}: _: prev: let
  pinnedPkgs = import nixpkgs-ollama {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = true;
  };
in {
  ollama-cuda-p5000 =
    (pinnedPkgs.ollama-cuda.override {
      cudaArches = ["sm_61"]; # ONLY P5000 - was building 6 architectures!
    }).overrideAttrs (old: {
      pname = "ollama-cuda-p5000";
      name = "ollama-cuda-p5000-${old.version}";
      vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
    });

  ollama = pinnedPkgs.ollama;
  open-webui = pinnedPkgs.open-webui;
}
