# vast-comfyui-hy3d (GEN-22)

Same stack as [`vast-comfyui-basic`](../vast-comfyui-basic/README.md), plus:

- [ComfyUI-Hunyuan3DWrapper](https://github.com/kijai/ComfyUI-Hunyuan3DWrapper) and [ComfyUI_essentials](https://github.com/cubiq/ComfyUI_essentials)
- Baked weights: `hunyuan3d-dit-v2-0-fp16.safetensors` under `/opt/baked-assets/models/diffusion_models/` (copied into `/workspace/models/diffusion_models/` on first boot)

**GHCR:** `ghcr.io/<OWNER>/vast-comfyui-hy3d:latest` (and SHA tags from Actions).

**Vast on-start (required):** `bash /usr/local/bin/vast-onstart-comfyui-hy3d.sh` — **do not** use `vast-onstart-comfyui.sh` (that is the **PlusTrellis** entrypoint from `vast-comfyui` and will install Trellis2/DINOv3 on boot). This image does not ship the Plus script; Hy3D + Basic-style ComfyUI only.

See [../vast-comfyui/README.md](../vast-comfyui/README.md) for ports, SSH, and private GHCR login on Vast.
