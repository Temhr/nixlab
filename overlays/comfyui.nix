# ComfyUI overlay with CUDA support for P5000
final: prev: {
  # ComfyUI with CUDA support for P5000
  # Uses Python packages from current nixpkgs but we'll override torch
  comfyui = prev.stdenv.mkDerivation rec {
    pname = "comfyui";
    version = "unstable-2024-11-30";

    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "master";
      sha256 = "sha256-pzklhRSicTu2GZS+sfd2x5Ph4IMvSq8LYlHo3gb1G54=";
    };

    nativeBuildInputs = [ prev.makeWrapper prev.autoPatchelfHook ];

    buildInputs = with prev; [
      python311
      stdenv.cc.cc.lib
      zlib
    ];

    # Use Python 3.11 packages
    propagatedBuildInputs = with prev.python311Packages; [
      pillow
      numpy
      safetensors
      aiohttp
      pyyaml
      tqdm
      psutil
      scipy
      einops
      opencv4
      matplotlib
      transformers
      accelerate
      sentencepiece
      # Don't include torch here - we'll add it via requirements at runtime
    ];

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/share/comfyui
      cp -r . $out/share/comfyui/

      # Create a requirements file for runtime installation
      cat > $out/share/comfyui/requirements-torch.txt <<EOF
--extra-index-url https://download.pytorch.org/whl/cu118
torch==2.2.2
torchvision==0.17.2
torchaudio==2.2.2
kornia
EOF

      mkdir -p $out/bin
      makeWrapper ${prev.python311}/bin/python $out/bin/comfyui \
        --add-flags "$out/share/comfyui/main.py" \
        --prefix PYTHONPATH : "${prev.python311.pkgs.makePythonPath propagatedBuildInputs}" \
        --prefix LD_LIBRARY_PATH : "${prev.lib.makeLibraryPath [ prev.stdenv.cc.cc.lib ]}" \
        --chdir "$out/share/comfyui"
    '';

    meta = with prev.lib; {
      description = "A powerful and modular stable diffusion GUI and backend";
      homepage = "https://github.com/comfyanonymous/ComfyUI";
      license = licenses.gpl3;
      platforms = platforms.linux;
    };
  };
}
