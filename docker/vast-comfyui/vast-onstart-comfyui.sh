#!/usr/bin/env bash
# Vast.ai on-start: map models to persistent /workspace and start ComfyUI in background.
set -euo pipefail
mkdir -p /workspace/models/checkpoints /workspace/models/clip /workspace/models/vae \
  /workspace/models/loras /workspace/models/upscale_models /workspace/models/controlnet \
  /workspace/models/embeddings /workspace/models/configs /workspace/models/vae_approx \
  /workspace/models/diffusers /workspace/models/gligen /workspace/models/hypernetworks \
  /workspace/models/photomaker /workspace/models/style_models /workspace/models/text_encoders

COMFY="/opt/ComfyUI"
if [[ -d "$COMFY/models" && ! -L "$COMFY/models" ]]; then
  rm -rf "$COMFY/models"
fi
ln -sfn /workspace/models "$COMFY/models"

cd "$COMFY"
# shellcheck source=/dev/null
source venv/bin/activate
if netstat -tuln 2>/dev/null | grep -q ':8188 '; then
  echo "Port 8188 already in use; skipping ComfyUI start."
  exit 0
fi
nohup python main.py --listen 0.0.0.0 --port 8188 --highvram >> /workspace/comfyui.log 2>&1 &
echo "ComfyUI starting on 8188 (logs: /workspace/comfyui.log)"
exit 0
