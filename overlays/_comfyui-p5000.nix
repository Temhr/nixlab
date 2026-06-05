# ComfyUI overlay with CUDA support for P5000
final: prev: {
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

  # comfyui now uses final.python311 and final.python311Packages
  # so it sees the patched aiosignal/aiohttp, not prev's originals
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
    buildInputs = [
      final.python311
      prev.stdenv.cc.cc.lib
      prev.zlib
    ];
    dontBuild = true;
    dontConfigure = true;
    installPhase = ''
      mkdir -p $out/share/comfyui
      cp -r . $out/share/comfyui/
      mkdir -p $out/bin
      makeWrapper ${final.python311}/bin/python $out/bin/comfyui \
        --add-flags "$out/share/comfyui/main.py" \
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
