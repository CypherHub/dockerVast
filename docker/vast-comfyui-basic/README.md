# vast-comfyui-basic (ComfyBasicInstall)

GHCR: **`ghcr.io/<OWNER>/vast-comfyui-basic:latest`** (+ SHA tags from Actions).

The **Dockerfile matches `docker/vast-comfyui`** (same ComfyUI stack, same `install-trellis2-runtime.sh` in the image). The only difference for **ComfyBasicInstall** is the Vast **on-start** script: **`vast-onstart-comfyui-basic.sh`** does **not** run Trellis2/DINOv3 on boot — same behavior as the single image you had before the split, when you don’t need Trellis.

**Vast On-start** (after `entrypoint.sh` if using Jupyter):

```bash
bash /usr/local/bin/vast-onstart-comfyui-basic.sh
```

Full Vast setup, ports, GHCR auth, and troubleshooting: see **[../vast-comfyui/README.md](../vast-comfyui/README.md)** (same §4 guidance; swap the script path above).

**Plus Trellis:** use image **`ghcr.io/<OWNER>/vast-comfyui`** and **`vast-onstart-comfyui.sh`** instead.
