# Takes the pinned nixpkgs sets as explicit args instead of pulling from prev
{
  unstableNixpkgs,
  stableNixpkgs,
  system,
}: _: _prev: let
  unstable = import unstableNixpkgs {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = true;
  };
  stable = import stableNixpkgs {
    inherit system;
    config.allowUnfree = true;
    config.cudaSupport = true;
  };
in {
  ollama-cuda-p5000 =
    (unstable.ollama-cuda.override {
      cudaArches = ["sm_61" "sm_75" "sm_80" "sm_86" "sm_89" "sm_90"];
    }).overrideAttrs (old: {
      pname = "ollama-cuda-p5000";
      name = "ollama-cuda-p5000-${old.version}";
      vendorHash = "";
    });

  ollama = stable.ollama;
}
