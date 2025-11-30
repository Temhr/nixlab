# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  modifications = final: prev: {
    # Create ollama-cuda-p5000 with compute capability 6.1 support
    # Pass cudaArches directly as a build parameter - this is the KEY!
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

    # ComfyUI with CUDA support for P5000
    comfyui = prev.python3Packages.buildPythonApplication rec {
      pname = "comfyui";
      version = "unstable-2024-11-30";
      src = prev.fetchFromGitHub {
        owner = "comfyanonymous";
        repo = "ComfyUI";
        rev = "master";  # Or pin to a specific commit
        sha256 = prev.lib.fakeSha256;  # Replace with actual hash after first build
      };
      propagatedBuildInputs = with prev.python3Packages; [
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
        spandrel
      ];
      # Don't run tests (ComfyUI doesn't have a standard test suite)
      doCheck = false;
      installPhase = ''
        mkdir -p $out/share/comfyui
        cp -r . $out/share/comfyui/

        mkdir -p $out/bin
        cat > $out/bin/comfyui <<EOF
        #!${prev.bash}/bin/bash
        cd $out/share/comfyui
        exec ${prev.python3}/bin/python main.py "\$@"
        EOF
        chmod +x $out/bin/comfyui
      '';
      meta = with prev.lib; {
        description = "A powerful and modular stable diffusion GUI and backend";
        homepage = "https://github.com/comfyanonymous/ComfyUI";
        license = licenses.gpl3;
        platforms = platforms.linux;
      };
    };
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
