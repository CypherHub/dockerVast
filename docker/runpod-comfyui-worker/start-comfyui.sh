#!/usr/bin/env bash
set -euo pipefail

export COMFYUI_DIR="${COMFYUI_DIR:-/opt/ComfyUI}"
export COMFYUI_HOST="${COMFYUI_HOST:-127.0.0.1}"
export COMFYUI_PORT="${COMFYUI_PORT:-8188}"
export COMFYUI_LOG="${COMFYUI_LOG:-/workspace/comfyui.log}"

mkdir -p /workspace/models /workspace/output /workspace/input

if [[ -d "$COMFYUI_DIR/models" && ! -L "$COMFYUI_DIR/models" ]]; then
  rm -rf "$COMFYUI_DIR/models"
fi
ln -sfn /workspace/models "$COMFYUI_DIR/models"

if pgrep -f "python main.py" >/dev/null 2>&1; then
  exit 0
fi

cd "$COMFYUI_DIR"
source venv/bin/activate
nohup python main.py --listen "$COMFYUI_HOST" --port "$COMFYUI_PORT" --highvram >"$COMFYUI_LOG" 2>&1 &
