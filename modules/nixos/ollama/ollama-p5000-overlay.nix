# Overlay to patch ollama-cuda for P5000 (compute capability 6.1)
# This should be added to nixpkgs.overlays in your configuration.nix

final: prev: {
  ollama-cuda-p5000 = prev.ollama-cuda.overrideAttrs (old: {
    name = "ollama-cuda-p5000-${old.version}";

    postPatch = (old.postPatch or "") + ''
      echo "===== PATCHING FOR P5000 (COMPUTE CAPABILITY 6.1) ====="

      # Patch gen_linux.sh if it exists
      if [ -f llm/generate/gen_linux.sh ]; then
        echo "Patching gen_linux.sh..."
        sed -i 's/CMAKE_CUDA_ARCHITECTURES=[0-9;"]*/CMAKE_CUDA_ARCHITECTURES="61"/g' llm/generate/gen_linux.sh
        grep CMAKE_CUDA_ARCHITECTURES llm/generate/gen_linux.sh || true
      fi

      # Patch any CMakeLists.txt files
      find llm -name CMakeLists.txt -type f | while read f; do
        echo "Patching $f..."
        sed -i 's/CMAKE_CUDA_ARCHITECTURES [0-9;"]*/CMAKE_CUDA_ARCHITECTURES "61"/g' "$f"
        sed -i 's/set(CMAKE_CUDA_ARCHITECTURES [^)]*)/set(CMAKE_CUDA_ARCHITECTURES "61")/g' "$f"
        grep -i cuda_arch "$f" || true
      done

      echo "===== PATCH COMPLETE ====="
    '';
  });
}
