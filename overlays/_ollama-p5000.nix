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
      cudaArches = ["sm_61" "sm_75" "sm_80" "sm_86" "sm_89" "sm_90"];
    }).overrideAttrs (old: {
      pname = "ollama-cuda-p5000";
      name = "ollama-cuda-p5000-${old.version}";
      vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
    });

  ollama = pinnedPkgs.ollama;
  open-webui = pinnedPkgs.open-webui;
}
