#!/usr/bin/env bash
# Hunyuan3D Wrapper + baked diffusion weights (runs with ComfyUI venv activated).
set -euo pipefail

cd /opt/ComfyUI/custom_nodes

clone_branch() {
  local url="$1" dir="$2"
  rm -rf "$dir"
  git clone --depth 1 "$url" "$dir"
  if [[ -f "$dir/requirements.txt" ]]; then pip install --no-cache-dir -r "$dir/requirements.txt"; fi
}

# Upstream Hy3D example workflows use essentials nodes.
clone_branch "https://github.com/cubiq/ComfyUI_essentials.git" "ComfyUI_essentials"

rm -rf ComfyUI-Hunyuan3DWrapper
git clone --depth 1 https://github.com/kijai/ComfyUI-Hunyuan3DWrapper.git ComfyUI-Hunyuan3DWrapper
cd ComfyUI-Hunyuan3DWrapper
pip install --no-cache-dir -r requirements.txt
pip install --no-cache-dir rembg omegaconf timm

python3 /tmp/patch_hy3dshape_pipelines.py hy3dshape/hy3dshape/pipelines.py

cd /opt/ComfyUI
pip install --no-cache-dir insightface || pip install --no-cache-dir insightface
pip install --no-cache-dir "numpy<2"

mkdir -p /opt/baked-assets/models/diffusion_models
HY3D_URL="https://huggingface.co/Kijai/Hunyuan3D-2_safetensors/resolve/main/hunyuan3d-dit-v2-0-fp16.safetensors"
HY3D_DST="/opt/baked-assets/models/diffusion_models/hunyuan3d-dit-v2-0-fp16.safetensors"
echo "Downloading Hunyuan3D diffusion weights to ${HY3D_DST} ..."
curl -fSL --retry 5 --retry-delay 5 --retry-all-errors \
  -A "Mozilla/5.0 (compatible; Docker-Build/1.0)" \
  -o "$HY3D_DST" \
  "$HY3D_URL"
echo "Hunyuan3D diffusion weights OK: ${HY3D_DST}"
