# ComfyUI overlay with CUDA support for P5000
final: prev: {
  comfyui = prev.stdenv.mkDerivation rec {
    pname = "comfyui";
    version = "unstable-2024-11-30";

    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "master";  # Or pin to a specific commit
      sha256 = prev.lib.fakeSha256;  # Replace with actual hash after first build
    };

    nativeBuildInputs = [ prev.makeWrapper ];

    buildInputs = with prev.python3Packages; [
      python
      torch-bin  # Use pre-built PyTorch with CUDA
      torchvision-bin
      torchaudio-bin
      pillow
      numpy
      safetensors
      aiohttp
      pyyaml
      tqdm
      psutil
      kornia
      scipy
      einops
    ];

    installPhase = ''
      mkdir -p $out/share/comfyui
      cp -r . $out/share/comfyui/

      mkdir -p $out/bin
      makeWrapper ${prev.python3}/bin/python $out/bin/comfyui \
        --add-flags "$out/share/comfyui/main.py" \
        --prefix PYTHONPATH : "${prev.python3.pkgs.makePythonPath buildInputs}" \
        --chdir "$out/share/comfyui"
    '';

    meta = with prev.lib; {
      description = "A powerful and modular stable diffusion GUI and backend";
      homepage = "https://github.com/comfyanonymous/ComfyUI";
      license = prev.lib.licenses.gpl3;
      platforms = prev.lib.platforms.linux;
    };
  };
}
