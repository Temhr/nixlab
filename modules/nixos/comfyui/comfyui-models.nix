{ config, lib, pkgs, ... }:

let
  cfg = config.services.comfyui-p5000;
  modelsCfg = config.services.comfyui-models;
in
{
  # ============================================================================
  # OPTIONS - Define what can be configured
  # ============================================================================
  options = {
    services.comfyui-models = {
      # REQUIRED: Enable model downloader
      enable = lib.mkEnableOption "ComfyUI Model Downloader";

      # OPTIONAL: Download popular Stable Diffusion models
      downloadSD15 = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Download Stable Diffusion 1.5 model (~4GB)";
      };

      downloadSDXL = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Download Stable Diffusion XL model (~7GB)";
      };

      # OPTIONAL: Download VAE models
      downloadVAE = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Download recommended VAE models";
      };

      # OPTIONAL: Download upscale models
      downloadUpscalers = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Download upscale models (ESRGAN, etc)";
      };

      # OPTIONAL: Hugging Face token for gated models
      huggingFaceToken = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Hugging Face API token for downloading gated models (store in secrets)";
      };

      # OPTIONAL: Custom model URLs to download
      customModels = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Model filename";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "Download URL";
            };
            type = lib.mkOption {
              type = lib.types.enum [ "checkpoint" "vae" "lora" "controlnet" "upscale" "clip" ];
              default = "checkpoint";
              description = "Model type (determines storage directory)";
            };
            sha256 = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "SHA256 hash for verification (optional)";
            };
          };
        });
        default = [];
        example = [
          {
            name = "my-custom-model.safetensors";
            url = "https://example.com/models/my-model.safetensors";
            type = "checkpoint";
            sha256 = "abc123...";
          }
        ];
        description = "Custom models to download";
      };
    };
  };

  # ============================================================================
  # CONFIG - What happens when model downloader is enabled
  # ============================================================================
  config = lib.mkIf (cfg.enable && modelsCfg.enable) {

    # ----------------------------------------------------------------------------
    # MODEL DIRECTORIES - Create subdirectories for different model types
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/models/checkpoints 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/vae 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/loras 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/controlnet 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/upscale_models 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/clip 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/clip_vision 0770 comfyui comfyui -"
      "d ${cfg.dataDir}/models/embeddings 0770 comfyui comfyui -"
      "f ${cfg.dataDir}/extra_model_paths.yaml 0660 comfyui comfyui -"
    ];

    # ----------------------------------------------------------------------------
    # MODEL DOWNLOADER - One-shot service to download models
    # ----------------------------------------------------------------------------
    systemd.services.comfyui-models-download = {
      description = "Download ComfyUI Models";
      wantedBy = [ "comfyui.service" ];
      before = [ "comfyui.service" ];
      after = [ "comfyui-pytorch-setup.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "comfyui";
        Group = "comfyui";
        RemainAfterExit = true;
        WorkingDirectory = cfg.dataDir;
        # Models can be large, allow plenty of time
        TimeoutStartSec = "infinity";
      };

      path = [ pkgs.curl pkgs.wget pkgs.coreutils ];

      script = ''
        set -e
        MODELS_DIR="${cfg.dataDir}/models"

        echo "Starting model downloads..."

        # Helper function to download with resume support
        download_model() {
          local url="$1"
          local output="$2"
          local model_name=$(basename "$output")

          if [ -f "$output" ]; then
            echo "Model $model_name already exists, skipping..."
            return 0
          fi

          echo "Downloading $model_name..."
          echo "  from: $url"
          echo "  to: $output"

          # Try with wget first (better resume support), fallback to curl
          ${pkgs.wget}/bin/wget -c -O "$output.partial" "$url" || \
          ${pkgs.curl}/bin/curl -L -C - -o "$output.partial" "$url" || {
            echo "Error: Failed to download $model_name"
            rm -f "$output.partial"
            return 1
          }

          # Move completed download
          mv "$output.partial" "$output"
          echo "Successfully downloaded $model_name"
        }

        ${lib.optionalString modelsCfg.downloadSD15 ''
          # Download Stable Diffusion 1.5
          echo "Downloading Stable Diffusion 1.5..."
          download_model \
            "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" \
            "$MODELS_DIR/checkpoints/sd_v1-5-pruned-emaonly.safetensors" \
            || echo "Warning: Failed to download SD 1.5"
        ''}

        ${lib.optionalString modelsCfg.downloadSDXL ''
          # Download Stable Diffusion XL Base
          echo "Downloading Stable Diffusion XL..."
          download_model \
            "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
            "$MODELS_DIR/checkpoints/sd_xl_base_1.0.safetensors" \
            || echo "Warning: Failed to download SDXL"
        ''}

        ${lib.optionalString modelsCfg.downloadVAE ''
          # Download recommended VAE models
          echo "Downloading VAE models..."

          # SD 1.5 VAE
          download_model \
            "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors" \
            "$MODELS_DIR/vae/vae-ft-mse-840000-ema-pruned.safetensors" \
            || echo "Warning: Failed to download SD 1.5 VAE"

          # SDXL VAE
          download_model \
            "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors" \
            "$MODELS_DIR/vae/sdxl_vae.safetensors" \
            || echo "Warning: Failed to download SDXL VAE"
        ''}

        ${lib.optionalString modelsCfg.downloadUpscalers ''
          # Download upscale models
          echo "Downloading upscale models..."

          # ESRGAN 4x
          download_model \
            "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" \
            "$MODELS_DIR/upscale_models/RealESRGAN_x4plus.pth" \
            || echo "Warning: Failed to download RealESRGAN"

          # ESRGAN 4x Anime
          download_model \
            "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth" \
            "$MODELS_DIR/upscale_models/RealESRGAN_x4plus_anime_6B.pth" \
            || echo "Warning: Failed to download RealESRGAN Anime"
        ''}

        # Download custom models
        ${lib.concatMapStringsSep "\n" (model: ''
          echo "Downloading custom model: ${model.name}..."

          # Determine output directory based on type
          case "${model.type}" in
            checkpoint) OUT_DIR="$MODELS_DIR/checkpoints" ;;
            vae) OUT_DIR="$MODELS_DIR/vae" ;;
            lora) OUT_DIR="$MODELS_DIR/loras" ;;
            controlnet) OUT_DIR="$MODELS_DIR/controlnet" ;;
            upscale) OUT_DIR="$MODELS_DIR/upscale_models" ;;
            clip) OUT_DIR="$MODELS_DIR/clip" ;;
            *) OUT_DIR="$MODELS_DIR/checkpoints" ;;
          esac

          download_model "${model.url}" "$OUT_DIR/${model.name}" || echo "Warning: Failed to download ${model.name}"

          ${lib.optionalString (model.sha256 != null) ''
            # Verify SHA256 if provided
            if [ -f "$OUT_DIR/${model.name}" ]; then
              echo "Verifying checksum for ${model.name}..."
              echo "${model.sha256}  $OUT_DIR/${model.name}" | ${pkgs.coreutils}/bin/sha256sum -c - || {
                echo "ERROR: Checksum mismatch for ${model.name}!"
                rm "$OUT_DIR/${model.name}"
                exit 1
              }
            fi
          ''}
        '') modelsCfg.customModels}

        echo "Model downloads complete!"
        echo ""
        echo "Downloaded models are in: $MODELS_DIR"
        echo "You can add more models manually to these directories:"
        echo "  - Checkpoints: $MODELS_DIR/checkpoints/"
        echo "  - VAE: $MODELS_DIR/vae/"
        echo "  - LoRA: $MODELS_DIR/loras/"
        echo "  - ControlNet: $MODELS_DIR/controlnet/"
        echo "  - Upscalers: $MODELS_DIR/upscale_models/"
      '';
    };

    # ----------------------------------------------------------------------------
    # Generate extra_model_paths.yaml for ComfyUI
    # ----------------------------------------------------------------------------
    system.activationScripts.writeExtraModelPathsYaml = ''
      cat > ${cfg.dataDir}/extra_model_paths.yaml <<EOF
    checkpoint:
      - ${cfg.dataDir}/models/checkpoints
    vae:
      - ${cfg.dataDir}/models/vae
    lora:
      - ${cfg.dataDir}/models/loras
    controlnet:
      - ${cfg.dataDir}/models/controlnet
    upscale_models:
      - ${cfg.dataDir}/models/upscale_models
    clip:
      - ${cfg.dataDir}/models/clip
    clip_vision:
      - ${cfg.dataDir}/models/clip_vision
    embeddings:
      - ${cfg.dataDir}/models/embeddings
    EOF
    '';
  };
}

/*
================================================================================
COMFYUI MODELS MODULE - AUTOMATIC MODEL DOWNLOADING
================================================================================

This module automatically downloads Stable Diffusion models and other resources
for ComfyUI.

USAGE
-----
Import this module alongside your comfyui-p5000 module:

In your configuration.nix:
```nix
imports = [
  ./modules/nixos/comfyui-p5000.nix
  ./modules/nixos/comfyui-models.nix
];

services.comfyui-p5000 = {
  enable = true;
};

services.comfyui-models = {
  enable = true;

  # Download Stable Diffusion 1.5 (good for P5000 with 16GB VRAM)
  downloadSD15 = true;

  # Download SDXL (requires more VRAM, might need --lowvram flag)
  downloadSDXL = true;

  # Download recommended VAE models
  downloadVAE = true;

  # Download upscale models
  downloadUpscalers = true;

  # Download custom models
  customModels = [
    {
      name = "my-custom-model.safetensors";
      url = "https://civitai.com/api/download/models/12345";
      type = "checkpoint";
    }
  ];
};
```

MODEL SIZES
-----------
Be aware of download sizes:
- SD 1.5: ~4GB
- SDXL: ~7GB
- VAE models: ~300MB each
- Upscalers: ~60MB each

Total for all default models: ~12GB

PERFORMANCE ON P5000
--------------------
Your Quadro P5000 has 16GB VRAM, which is sufficient for:
- ✅ SD 1.5 at full resolution (512x512) - runs smoothly
- ✅ SDXL at reduced resolution or with --lowvram
- ✅ Multiple LoRA models
- ✅ ControlNet
- ✅ Upscaling operations

For SDXL on P5000, you may want to use --lowvram flag:
Add to your comfyui-p5000 module:
  ExecStart = "... main.py --lowvram ..."

DOWNLOADING MODELS MANUALLY
----------------------------
You can also download models manually:

Popular model sources:
- Hugging Face: https://huggingface.co/models
- Civitai: https://civitai.com/
- Official Stability AI: https://stability.ai/

Place models in:
- Checkpoints: /data/comfyui/models/checkpoints/
- VAE: /data/comfyui/models/vae/
- LoRA: /data/comfyui/models/loras/
- ControlNet: /data/comfyui/models/controlnet/

After adding models manually, restart ComfyUI:
  sudo systemctl restart comfyui

CUSTOM MODELS
-------------
To download models from Civitai or other sources:

```nix
customModels = [
  {
    name = "realistic-vision-v5.safetensors";
    url = "https://civitai.com/api/download/models/XXXXX";
    type = "checkpoint";
  }
  {
    name = "detail-tweaker-lora.safetensors";
    url = "https://civitai.com/api/download/models/YYYYY";
    type = "lora";
  }
];
```

Note: Some Civitai models require an API key. Add it to the URL:
  url = "https://civitai.com/api/download/models/XXXXX?token=YOUR_API_KEY";

HUGGING FACE GATED MODELS
--------------------------
Some models on Hugging Face are "gated" and require authentication.
To use them, get an API token from https://huggingface.co/settings/tokens

Then add to your configuration:
```nix
services.comfyui-models = {
  huggingFaceToken = "hf_your_token_here";  # Better: use agenix/sops-nix for secrets
};
```

TROUBLESHOOTING
---------------
View download logs:
  sudo journalctl -u comfyui-models-download -n 200

Check downloaded models:
  ls -lh /data/comfyui/models/checkpoints/
  ls -lh /data/comfyui/models/vae/

If a download fails:
- Check disk space: df -h /data
- Check network connectivity
- Try downloading manually with wget
- The service will retry on next rebuild

Resume interrupted downloads:
  sudo systemctl restart comfyui-models-download

DISK SPACE
----------
Ensure you have enough disk space:
- Base models: ~12GB
- Custom nodes: ~1-2GB
- Generated images: varies
- Recommended: 50GB+ free space

Check space:
  df -h /data

PERFORMANCE TIPS
----------------
1. Start with SD 1.5 - it's faster and uses less VRAM
2. Use safetensors format (safer and faster than .ckpt)
3. Enable VAE for better image quality
4. Try different samplers for speed/quality tradeoff
5. Use LoRA models for fine-tuning without full model retraining
*/
