# Ollama overlay with CUDA P5000 support
final: prev: {
  # Fix ctranslate2 compilation error (missing cstdint include)
  ctranslate2 = prev.ctranslate2.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      sed -i '1i#include <cstdint>' third_party/cxxopts/include/cxxopts.hpp
    '';
  });

  # Fix duckdb-engine test failures and extract-msg version constraints
  python313 = prev.python313.override {
    packageOverrides = pyfinal: pyprev: {
      duckdb-engine = pyprev.duckdb-engine.overridePythonAttrs (old: {
        doCheck = false;  # Skip tests - pg_catalog queries fail in test suite
      });
      extract-msg = pyprev.extract-msg.overridePythonAttrs (old: {
        # Relax beautifulsoup4 version constraint
        postPatch = (old.postPatch or "") + ''
          substituteInPlace pyproject.toml \
            --replace-fail 'beautifulsoup4<4.14,>=4.11.1' 'beautifulsoup4>=4.11.1'
        '';
      });
    };
  };

  # Create ollama-cuda-p5000 with compute capability 6.1 support
  # Pass cudaArches directly as a build parameter
  ollama-cuda-p5000 = (prev.ollama-cuda.override {
    # sm_61 is compute capability 6.1 for P5000
    cudaArches = [ "sm_61" "sm_75" "sm_80" "sm_86" "sm_89" "sm_90" ];
  }).overrideAttrs (old: {
    # Change the name to force Nix to rebuild
    pname = "ollama-cuda-p5000";
    name = "ollama-cuda-p5000-${old.version}";
  });

  # Use stable Ollama for better GPU compatibility
  ollama = final.stable.ollama;
}
