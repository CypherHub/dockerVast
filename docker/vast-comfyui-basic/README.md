# vast-comfyui-basic (ComfyBasicInstall)

GHCR: **`ghcr.io/<OWNER>/vast-comfyui-basic:latest`** (+ SHA tags from Actions).

Same ComfyUI stack as **`vast-comfyui`** (Manager, Webhook, Crystools, ReActor, etc.) but **no** ComfyUI-Trellis2 first-boot install and **no** DINOv3 download. Use this template when you only need standard Comfy workflows.

**Vast On-start** (after `entrypoint.sh` if using Jupyter):

```bash
bash /usr/local/bin/vast-onstart-comfyui-basic.sh
```

Full Vast setup, ports, GHCR auth, and troubleshooting: see **[../vast-comfyui/README.md](../vast-comfyui/README.md)** (same §4 guidance; swap the script path above).

**Plus Trellis:** use image **`ghcr.io/<OWNER>/vast-comfyui`** and **`vast-onstart-comfyui.sh`** instead.
