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

  # Python fixes from _open-webui.nix
  ctranslate2 = prev.ctranslate2.overrideAttrs (oldAttrs: {
    postPatch =
      (oldAttrs.postPatch or "")
      + ''
        sed -i '1i#include <cstdint>' third_party/cxxopts/include/cxxopts.hpp
      '';
  });

  python313 = prev.python313.override {
    packageOverrides = _: pyprev: {
      duckdb-engine = pyprev.duckdb-engine.overridePythonAttrs (_: {doCheck = false;});
      langchain-community = pyprev.langchain-community.overridePythonAttrs (_: {doCheck = false;});
      extract-msg = pyprev.extract-msg.overridePythonAttrs (_: {dontCheckRuntimeDeps = true;});
    };
  };
}
