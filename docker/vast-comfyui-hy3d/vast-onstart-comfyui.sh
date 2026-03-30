#!/usr/bin/env bash
# Vast.ai on-start: map models to persistent /workspace and start ComfyUI in background.
set -euo pipefail
mkdir -p /workspace
echo "[$(date -Iseconds)] vast-onstart-comfyui.sh starting" >> /workspace/onstart.log
# SSH: so the public key you add in Vast is accepted on every new VM.
if command -v sshd >/dev/null 2>&1; then
  /usr/sbin/sshd 2>/dev/null || service ssh start 2>/dev/null || true
fi
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
  if ! wget -q -T 120 -O /workspace/models/insightface/inswapper_128.onnx "$INSWAP_URL" \
    && ! curl -fsSL -o /workspace/models/insightface/inswapper_128.onnx "$INSWAP_URL"; then
    echo "[vast-onstart] WARN: inswapper download failed (ReActor may error); continuing ComfyUI start." | tee -a /workspace/onstart.log
  fi
fi

# Models symlink first so ComfyUI can start without waiting for Trellis2/DINOv3.
if [[ -d "$COMFY/models" && ! -L "$COMFY/models" ]]; then
  rm -rf "$COMFY/models"
fi
ln -sfn /workspace/models "$COMFY/models"

# Detect listener on 8188 (avoid false negatives from netstat column layout).
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
  # Start ComfyUI first so 8188 is up quickly; Trellis2/DINOv3 run in background and must not block.
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

# Trellis2 + DINOv3: first-boot only, run in background so they never block or abort on-start.
(
  TMARK=/workspace/.trellis2_runtime_ok
  if [[ ! -f "$TMARK" ]]; then
    echo "[vast-onstart] Installing ComfyUI-Trellis2 (first boot, see /workspace/trellis2-install.log)..."
    if bash /usr/local/bin/install-trellis2-runtime.sh >> /workspace/trellis2-install.log 2>&1; then
      touch "$TMARK"
    else
      echo "[vast-onstart] Trellis2 install failed — check /workspace/trellis2-install.log (will retry next boot)."
    fi
  fi
  DINO_MARK=/workspace/models/facebook/.dinov3_vitl16_ready
  if [[ ! -f "$DINO_MARK" ]]; then
    echo "[vast-onstart] Downloading DINOv3 for Trellis2 (first run, large — /workspace/dinov3-download.log)..."
    mkdir -p /workspace/models/facebook
    source /opt/ComfyUI/venv/bin/activate
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
) &
exit 0
