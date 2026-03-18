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

# ComfyUI-Trellis2 — pip/meshlib fails on GHCR runners; install once on Vast (see /workspace/trellis2-install.log).
TMARK=/workspace/.trellis2_runtime_ok
if [[ ! -f "$TMARK" ]]; then
  echo "[vast-onstart] Installing ComfyUI-Trellis2 (first boot, several min)..."
  if bash /usr/local/bin/install-trellis2-runtime.sh >> /workspace/trellis2-install.log 2>&1; then
    touch "$TMARK"
  else
    echo "[vast-onstart] Trellis2 install failed — check /workspace/trellis2-install.log (will retry next boot)."
  fi
fi

# Trellis2 DINOv3 — first boot only (marker on persistent /workspace).
DINO_MARK=/workspace/models/facebook/.dinov3_vitl16_ready
if [[ ! -f "$DINO_MARK" ]]; then
  echo "[vast-onstart] Downloading DINOv3 for Trellis2 (first run, large — /workspace/dinov3-download.log)..."
  mkdir -p /workspace/models/facebook
  # shellcheck source=/dev/null
  source "$COMFY/venv/bin/activate"
  pip install -q huggingface_hub 2>/dev/null || true
  python - <<'PY' >> /workspace/dinov3-download.log 2>&1
from huggingface_hub import snapshot_download
dest = "/workspace/models/facebook/dinov3-vitl16-pretrain-lvd1689m"
snapshot_download(
    repo_id="facebook/dinov3-vitl16-pretrain-lvd1689m",
    local_dir=dest,
    local_dir_use_symlinks=False,
)
open("/workspace/models/facebook/.dinov3_vitl16_ready", "w").write("ok\n")
print("DINOv3 OK", dest)
PY
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
