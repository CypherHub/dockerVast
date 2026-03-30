# vast-comfyui-hy3d (GEN-22)

Same stack as [`vast-comfyui-basic`](../vast-comfyui-basic/README.md), plus:

- [ComfyUI-Hunyuan3DWrapper](https://github.com/kijai/ComfyUI-Hunyuan3DWrapper) and [ComfyUI_essentials](https://github.com/cubiq/ComfyUI_essentials)
- Baked weights: `hunyuan3d-dit-v2-0-fp16.safetensors` under `/opt/baked-assets/models/diffusion_models/` (copied into `/workspace/models/diffusion_models/` on first boot)

**GHCR:** `ghcr.io/<OWNER>/vast-comfyui-hy3d:latest` (and SHA tags from Actions).

**Vast on-start:** `bash /usr/local/bin/vast-onstart-comfyui-hy3d.sh` (no Trellis2/DINO on boot; same pattern as Basic).

See [../vast-comfyui/README.md](../vast-comfyui/README.md) for ports, SSH, and private GHCR login on Vast.
