#!/usr/bin/env bash
# Vast.ai on-start: map models to persistent /workspace and start ComfyUI in background.
set -euo pipefail
mkdir -p /workspace/models/checkpoints /workspace/models/clip /workspace/models/vae \
  /workspace/models/loras /workspace/models/upscale_models /workspace/models/controlnet \
  /workspace/models/embeddings /workspace/models/configs /workspace/models/vae_approx \
  /workspace/models/diffusers /workspace/models/gligen /workspace/models/hypernetworks \
  /workspace/models/photomaker /workspace/models/style_models /workspace/models/text_encoders \
  /workspace/models/insightface /workspace/models/facebook

COMFY="/opt/ComfyUI"
# ReActor installs inswapper_128.onnx under ComfyUI/models/insightface at image build time.
# We replace ComfyUI/models with a symlink to /workspace — copy insightface first or ReActor sees [].
if [[ -d "$COMFY/models" && ! -L "$COMFY/models" && -d "$COMFY/models/insightface" ]]; then
  shopt -s nullglob
  for f in "$COMFY/models/insightface"/*; do
    base=$(basename "$f")
    [[ -e "/workspace/models/insightface/$base" ]] || cp -a "$f" "/workspace/models/insightface/"
  done
  shopt -u nullglob
fi
INSWAP_URL="https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx"
if [[ ! -s /workspace/models/insightface/inswapper_128.onnx ]]; then
  echo "[vast-onstart] Downloading inswapper_128.onnx for ComfyUI-ReActor..."
  wget -q -T 120 -O /workspace/models/insightface/inswapper_128.onnx "$INSWAP_URL" \
    || curl -fsSL -o /workspace/models/insightface/inswapper_128.onnx "$INSWAP_URL"
fi

if [[ -d "$COMFY/models" && ! -L "$COMFY/models" ]]; then
  rm -rf "$COMFY/models"
fi
ln -sfn /workspace/models "$COMFY/models"

if netstat -tuln 2>/dev/null | grep -q ':8188 '; then
  echo "Port 8188 already in use; skipping ComfyUI start."
  exit 0
fi
# nohup + detached bash: survives on-start script exit (SIGHUP). Restart loop after crashes.
nohup bash -c '
  cd /opt/ComfyUI && source venv/bin/activate
  while true; do
    python main.py --listen 0.0.0.0 --port 8188 --highvram >> /workspace/comfyui.log 2>&1
    ec=$?
    echo "[$(date -Iseconds)] ComfyUI exited (code ${ec}); restarting in 10s..." >> /workspace/comfyui.log
    sleep 10
  done
' >/dev/null 2>&1 &
echo "ComfyUI supervisor on 8188 (auto-restart on crash; logs: /workspace/comfyui.log)"
exit 0
