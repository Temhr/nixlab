# ComfyUI overlay with CUDA support for P5000
_: prev: {
  python311 = prev.python311.override {
    packageOverrides = final: pyprev: {
      terminado = pyprev.terminado.overridePythonAttrs (_: {
        doCheck = false;
      });
      einops = pyprev.einops.overridePythonAttrs (_: {
        doCheck = false;
      });
      # Strip sphinx from aiosignal — it's a doc-only dep, not runtime
      aiosignal = pyprev.aiosignal.overridePythonAttrs (_: {
        propagatedBuildInputs = [ pyprev.frozenlist ];
        doCheck = false;
      });
      # aiohttp must also be overridden so it picks up the patched aiosignal
      # via `final` (the fixed-point) rather than pyprev's original
      aiohttp = pyprev.aiohttp.overridePythonAttrs (old: {
        propagatedBuildInputs = map
          (dep: if (dep.pname or "") == "aiosignal" then final.aiosignal else dep)
          (old.propagatedBuildInputs or []);
        doCheck = false;
      });
    };
  };

  # PyTorch 2.2.2 cu118 wheels fetched into the Nix store with pinned hashes.
  # These are Fixed Output Derivations: reproducible, offline after first fetch,
  # and hash-verified — no network access at boot.
  #
  # To obtain hashes, run:
  #   nix store prefetch-file --hash-type sha256 \
  #     "https://download.pytorch.org/whl/cu118/torch-2.2.2%2Bcu118-cp311-cp311-linux_x86_64.whl"
  # (repeat for torchvision and torchaudio)
  pytorchCu118Wheels = {
    torch = prev.fetchurl {
      name = "torch-2.2.2-cu118-cp311-linux_x86_64.whl";
      url = "https://download.pytorch.org/whl/cu118/torch-2.2.2%2Bcu118-cp311-cp311-linux_x86_64.whl";
      hash = "sha256-jAJgR8apIPCq4qC99w28lvNXSCXVCVefUTH0zyrpAIQ=";
    };
    torchvision = prev.fetchurl {
      name = "torchvision-0.17.2-cu118-cp311-linux_x86_64.whl";
      url = "https://download.pytorch.org/whl/cu118/torchvision-0.17.2%2Bcu118-cp311-cp311-linux_x86_64.whl";
      hash = "sha256-lh2cqDZNa/tAY5AvHXPYS0RvpRos8NH7TNZDIS5PjAc=";
    };
    torchaudio = prev.fetchurl {
      name = "torchaudio-2.2.2-cu118-cp311-linux_x86_64.whl";
      url = "https://download.pytorch.org/whl/cu118/torchaudio-2.2.2%2Bcu118-cp311-cp311-linux_x86_64.whl";
      hash = "sha256-V0i0eIeR5sTlchpc6kK8oksyxF35XtUIHVHRAUDN68A=";
    };
  };

  # ComfyUI package — source pinned via fetchFromGitHub hash
  comfyui = prev.stdenv.mkDerivation rec {
    pname = "comfyui";
    version = "unstable-2024-11-30";
    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "a0ae3f3bd46b9e58f43fccfe17077873bf16f905";
      sha256 = "sha256-tv1IclHucV42JSVpxO/IdsOm+j6a5UcmZ+wBThZEhkY=";
    };
    nativeBuildInputs = [prev.makeWrapper prev.autoPatchelfHook];
    buildInputs = with prev; [
      python311
      stdenv.cc.cc.lib
      zlib
    ];
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
      # torch is NOT included here — it is installed into the venv
      # from the Nix store wheels in pytorchCu118Wheels.
    ];
    dontBuild = true;
    dontConfigure = true;
    installPhase = ''
      mkdir -p $out/share/comfyui
      cp -r . $out/share/comfyui/
      mkdir -p $out/bin
      makeWrapper ${prev.python311}/bin/python $out/bin/comfyui \
        --add-flags "$out/share/comfyui/main.py" \
        --prefix PYTHONPATH : "${prev.python311.pkgs.makePythonPath propagatedBuildInputs}" \
        --prefix LD_LIBRARY_PATH : "${prev.lib.makeLibraryPath [prev.stdenv.cc.cc.lib]}" \
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
