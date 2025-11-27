# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  modifications = final: prev: {
    # Create ollama-cuda-p5000 with compute capability 6.1 support
    ollama-cuda-p5000 = prev.ollama-cuda.overrideAttrs (old: {
      name = "ollama-cuda-p5000-${old.version}";

      postPatch = (old.postPatch or "") + ''
        echo "===== PATCHING FOR P5000 (COMPUTE CAPABILITY 6.1) ====="

        # Patch gen_linux.sh if it exists
        if [ -f llm/generate/gen_linux.sh ]; then
          echo "Patching gen_linux.sh..."
          sed -i 's/CMAKE_CUDA_ARCHITECTURES="[^"]*"/CMAKE_CUDA_ARCHITECTURES="61"/g' llm/generate/gen_linux.sh
          sed -i 's/CMAKE_CUDA_ARCHITECTURES=[0-9;]*/CMAKE_CUDA_ARCHITECTURES=61/g' llm/generate/gen_linux.sh
          echo "After patch:"
          grep CMAKE_CUDA_ARCHITECTURES llm/generate/gen_linux.sh || echo "No CMAKE_CUDA_ARCHITECTURES found"
        fi

        # Patch any CMakeLists.txt files
        find llm -name CMakeLists.txt -type f -exec echo "Found: {}" \;
        find llm -name CMakeLists.txt -type f | while read f; do
          echo "Patching $f..."
          sed -i 's/CMAKE_CUDA_ARCHITECTURES "[^"]*"/CMAKE_CUDA_ARCHITECTURES "61"/g' "$f"
          sed -i 's/set(CMAKE_CUDA_ARCHITECTURES [^)]*)/set(CMAKE_CUDA_ARCHITECTURES "61")/g' "$f"
        done

        echo "===== PATCH COMPLETE ====="
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
