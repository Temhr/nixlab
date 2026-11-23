# ComfyUI overlay for P5000 — source tree only.
# Python deps (PyTorch cu126 + ComfyUI requirements) are installed into a venv
# by the comfyui-pytorch-setup service in comfyui-p5000.nix.
_: prev: {
  comfyui = prev.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "comfyui";
    # Newest tag: https://github.com/Comfy-Org/ComfyUI/releases
    version = "0.46.0";

    src = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "ComfyUI";
      rev = "v${finalAttrs.version}";
      # Build once, then paste the real hash from the "got:" line.
      hash = "sha256-2F43abzhKX/fKdmPa+bhS9/hB0q4SqzpVYThKlNwYMU="; #prev.lib.fakeHash;
    };

    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/comfyui
      cp -r . $out/share/comfyui/
    '';

    meta = {
      description = "Modular stable diffusion GUI and backend";
      homepage = "https://github.com/Comfy-Org/ComfyUI";
      license = prev.lib.licenses.gpl3Only;
      platforms = prev.lib.platforms.linux;
    };
  });
}
