#!/usr/bin/env bash
# Install ComfyUI custom nodes (GEN-10 template). Run with venv activated from /opt/ComfyUI.
set -euo pipefail
cd /opt/ComfyUI/custom_nodes

clone_branch() {
  local url="$1" dir="$2"
  rm -rf "$dir"
  git clone --depth 1 "$url" "$dir"
  if [[ -f "$dir/requirements.txt" ]]; then pip install -r "$dir/requirements.txt"; fi
}

clone_rev() {
  local url="$1" dir="$2" rev="$3"
  rm -rf "$dir"
  mkdir "$dir"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$url"
  git -C "$dir" fetch --depth 1 origin "$rev"
  git -C "$dir" checkout -q FETCH_HEAD
  if [[ -f "$dir/requirements.txt" ]]; then pip install -r "$dir/requirements.txt"; fi
}

clone_branch "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"
clone_branch "https://github.com/pawelmal0101/ComfyUI-Webhook.git" "ComfyUI-Webhook"
clone_branch "https://github.com/crystian/ComfyUI-Crystools.git" "ComfyUI-Crystools"

clone_rev "https://github.com/jerrywap/ComfyUI_LoadImageFromHttpURL.git" "ComfyUI_LoadImageFromHttpURL" "90f240025c6e3efaf8becfce764e8d38c51197ef"
clone_rev "https://github.com/ComfyUI-Workflow/ComfyUI-OpenAI.git" "ComfyUI-OpenAI" "89e2e57b02d3865aa9349076d2f373513e8afd0b"
clone_rev "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "ComfyUI-VideoHelperSuite" "8e4d79471bf1952154768e8435a9300077b534fa"

clone_rev "https://github.com/Gourieff/ComfyUI-ReActor.git" "ComfyUI-ReActor" "9b17e4cea53769d7157e507659adbbe09a3114fe"
if [[ -f ComfyUI-ReActor/scripts/reactor_sfw.py ]]; then
  sed -i '54s/return True/return False/' ComfyUI-ReActor/scripts/reactor_sfw.py || true
fi
pip install -r ComfyUI-ReActor/requirements.txt
pip install "onnxruntime-gpu>=1.17.0" insightface || pip install onnxruntime insightface
( cd ComfyUI-ReActor && python install.py )

cd /opt/ComfyUI
pip install importlib_metadata
