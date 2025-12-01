# Ollama overlay with CUDA P5000 support
final: prev: {
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
