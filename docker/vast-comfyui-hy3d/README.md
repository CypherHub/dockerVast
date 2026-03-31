# vast-comfyui-hy3d (GEN-22)

**Dockerfile `FROM ghcr.io/<OWNER>/vast-comfyui-basic:latest`** — same runtime as the working Basic image, then adds:

- [ComfyUI-Hunyuan3DWrapper](https://github.com/kijai/ComfyUI-Hunyuan3DWrapper) and [ComfyUI_essentials](https://github.com/cubiq/ComfyUI_essentials)
- Baked weights: `hunyuan3d-dit-v2-0-fp16.safetensors` under `/opt/baked-assets/models/diffusion_models/` (copied into `/workspace/models/diffusion_models/` on first boot)
- Compatibility patch: force `transparent_background` (used by `ComfyUI_essentials`) to run on CPU with JIT off to avoid older-GPU CUDA kernel-image errors.

**GHCR:** `ghcr.io/<OWNER>/vast-comfyui-hy3d:latest` (and SHA tags from Actions). CI logs into GHCR so the base image can be pulled.

**Vast on-start:** Prefer `bash /usr/local/bin/vast-onstart-comfyui-hy3d.sh`. Templates that still call **`vast-onstart-comfyui.sh`** also work: it is a **symlink** to the Hy3D script (not Plus/Trellis).

See [../vast-comfyui/README.md](../vast-comfyui/README.md) for ports, SSH, and private GHCR login on Vast.
