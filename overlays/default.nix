# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  modifications = final: prev: {
    # Create ollama-cuda-p5000 with compute capability 6.1 support
    ollama-cuda-p5000 = prev.ollama-cuda.overrideAttrs (old: {
      name = "ollama-cuda-p5000-${old.version}";

      preBuild = ''
        ${old.preBuild or ""}

        echo "===== BUILDING LLAMA.CPP FOR P5000 (COMPUTE CAPABILITY 6.1) ====="

        cd llm/llama.cpp
        cmake -B build \
          -DCMAKE_SKIP_BUILD_RPATH=ON \
          -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
          -DCMAKE_CUDA_ARCHITECTURES='61' \
          .
        cmake --build build -j $NIX_BUILD_CORES
        cd ../..

        echo "===== BUILD COMPLETE ====="
      '';
    });

    # Use stable Ollama for better GPU compatibility
    ollama = final.stable.ollama;
  };

  # When applied, the stable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.stable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
      config.cudaSupport = true;  # Enable CUDA support in stable packages
    };
  };
}
