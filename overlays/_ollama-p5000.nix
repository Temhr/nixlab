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
in {
  ollama-cuda-p5000 =
    (pinnedPkgs.ollama-cuda.override {
      cudaArches = ["sm_61" "sm_75" "sm_80" "sm_86" "sm_89" "sm_90"];
    }).overrideAttrs (old: {
      pname = "ollama-cuda-p5000";
      name = "ollama-cuda-p5000-${old.version}";
      vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
    });

  ollama = stablePkgs.ollama;
  open-webui = webuiPkgs.open-webui;
}
