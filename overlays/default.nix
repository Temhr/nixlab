# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  modifications = final: prev: {
    # Create ollama-cuda-p5000 with compute capability 6.1 support
    ollama-cuda-p5000 = prev.ollama-cuda.overrideAttrs (old: {
      name = "ollama-cuda-p5000-${old.version}-cc61v2";  # v2 to force rebuild
      pname = "ollama-cuda-p5000-cc61v2";

      # Set environment variable that llama.cpp's CMakeLists.txt will read
      env = (old.env or {}) // {
        CMAKE_CUDA_ARCHITECTURES = "61";
      };

      postPatch = (old.postPatch or "") + ''
        echo "===== PATCHING FOR P5000 (COMPUTE CAPABILITY 6.1) ====="

        # Find all CMakeLists.txt and set CUDA architectures
        find . -name CMakeLists.txt -type f -exec echo "Found CMakeLists.txt: {}" \;

        # Patch the generate script if it exists
        if [ -f llm/generate/gen_linux.sh ]; then
          echo "Patching llm/generate/gen_linux.sh"
          # Add or replace CMAKE_CUDA_ARCHITECTURES in the cmake command
          sed -i 's|-DCMAKE_CUDA_ARCHITECTURES=[^ ]*|-DCMAKE_CUDA_ARCHITECTURES=61|g' llm/generate/gen_linux.sh
          # If it doesn't exist, add it after the cmake command starts
          if ! grep -q "CMAKE_CUDA_ARCHITECTURES" llm/generate/gen_linux.sh; then
            sed -i '/cmake -S/a\  -DCMAKE_CUDA_ARCHITECTURES=61 \\' llm/generate/gen_linux.sh
          fi
          echo "Contents of gen_linux.sh after patch:"
          cat llm/generate/gen_linux.sh
        fi

        # Patch CMakeLists.txt files directly
        for f in $(find . -name CMakeLists.txt -type f); do
          if grep -q "CMAKE_CUDA_ARCHITECTURES" "$f"; then
            echo "Patching $f"
            sed -i 's/set(CMAKE_CUDA_ARCHITECTURES .*/set(CMAKE_CUDA_ARCHITECTURES "61")/g' "$f"
            sed -i 's/CMAKE_CUDA_ARCHITECTURES "[^"]*"/CMAKE_CUDA_ARCHITECTURES "61"/g' "$f"
          fi
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
