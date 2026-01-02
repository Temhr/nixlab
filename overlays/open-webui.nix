# open-webui support
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
      langchain-community = pyprev.langchain-community.overridePythonAttrs (old: {
        doCheck = false;  # Skip tests - depends on duckdb-engine tests that fail
      });
      extract-msg = pyprev.extract-msg.overridePythonAttrs (old: {
        # Skip runtime dependency version check for beautifulsoup4
        dontCheckRuntimeDeps = true;
      });
    };
  };
}
