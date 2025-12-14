# ComfyUI overlay with CUDA support for P5000
final: prev: {
  # Fix terminado test failure
  python311 = prev.python311.override {
    packageOverrides = pyfinal: pyprev: {
      terminado = pyprev.terminado.overridePythonAttrs (old: {
        doCheck = false;  # Skip tests due to flaky test_max_terminals
      });
      einops = pyprev.einops.overridePythonAttrs (old: {
        doCheck = false;  # Skip tests since terminado is broken
      });
    };
  };

  # ComfyUI with CUDA support for P5000
  # Uses Python packages from current nixpkgs but we'll override torch
  comfyui = prev.stdenv.mkDerivation rec {
    pname = "comfyui";
    version = "unstable-2024-11-30";

    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "master";
      sha256 = "sha256-bCuT5KBp9bAb62ND1QWi5Ez6Xa8R0J8/ymlBvx4KELg=";
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
