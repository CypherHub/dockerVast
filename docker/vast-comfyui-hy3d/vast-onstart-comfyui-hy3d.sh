#!/usr/bin/env bash
# Vast.ai on-start — Hy3D: same as ComfyBasicInstall + seed Hunyuan3D DiT weights into /workspace.
set -euo pipefail
mkdir -p /workspace
echo "[$(date -Iseconds)] vast-onstart-comfyui-hy3d.sh starting" >> /workspace/onstart.log
if command -v sshd >/dev/null 2>&1; then
  /usr/sbin/sshd 2>/dev/null || service ssh start 2>/dev/null || true
fi
mkdir -p /workspace/models/checkpoints /workspace/models/clip /workspace/models/vae \
  /workspace/models/loras /workspace/models/upscale_models /workspace/models/controlnet \
  /workspace/models/embeddings /workspace/models/configs /workspace/models/vae_approx \
  /workspace/models/diffusers /workspace/models/gligen /workspace/models/hypernetworks \
  /workspace/models/photomaker /workspace/models/style_models /workspace/models/text_encoders \
  /workspace/models/insightface /workspace/models/facebook /workspace/models/diffusion_models

COMFY="/opt/ComfyUI"
HY3D_BAKED="/opt/baked-assets/models/diffusion_models/hunyuan3d-dit-v2-0-fp16.safetensors"
if [[ -f "$HY3D_BAKED" ]]; then
  if [[ ! -s /workspace/models/diffusion_models/hunyuan3d-dit-v2-0-fp16.safetensors ]]; then
    echo "[vast-onstart] Copying baked Hunyuan3D DiT weights to /workspace/models/diffusion_models ..."
    cp -a "$HY3D_BAKED" /workspace/models/diffusion_models/hunyuan3d-dit-v2-0-fp16.safetensors
  fi
else
  echo "[vast-onstart] WARN: baked Hy3D weights missing at $HY3D_BAKED" | tee -a /workspace/onstart.log
fi

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
  if ! wget -q -T 120 -O /workspace/models/insightface/inswapper_128.onnx "$INSWAP_URL" \
    && ! curl -fsSL -o /workspace/models/insightface/inswapper_128.onnx "$INSWAP_URL"; then
    echo "[vast-onstart] WARN: inswapper download failed (ReActor may error); continuing ComfyUI start." | tee -a /workspace/onstart.log
  fi
fi

if [[ -d "$COMFY/models" && ! -L "$COMFY/models" ]]; then
  rm -rf "$COMFY/models"
fi
ln -sfn /workspace/models "$COMFY/models"

_port8188_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -tuln 2>/dev/null | grep -qE ':(8188)\b'
    return $?
  fi
  netstat -tuln 2>/dev/null | grep -qE ':(8188)\b'
}
if _port8188_in_use; then
  echo "Port 8188 already in use; skipping ComfyUI start." | tee -a /workspace/onstart.log
else
  nohup bash -c '
    cd /opt/ComfyUI && source venv/bin/activate
    while true; do
      python main.py --listen 0.0.0.0 --port 8188 --highvram >> /workspace/comfyui.log 2>&1
      ec=$?
      echo "[$(date -Iseconds)] ComfyUI exited (code ${ec}); restarting in 10s..." >> /workspace/comfyui.log
      sleep 10
    done
  ' >/dev/null 2>&1 &
  echo "ComfyUI supervisor on 8188 (auto-restart on crash; logs: /workspace/comfyui.log)" | tee -a /workspace/onstart.log
fi
exit 0
