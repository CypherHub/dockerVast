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
python3 - <<'PY'
from pathlib import Path

p = Path("/opt/ComfyUI/custom_nodes/ComfyUI_essentials/image.py")
s = p.read_text()
old = "self.session = Remover(mode=mode, jit=use_jit)"
new = "self.session = Remover(mode=mode, jit=False, device='cpu')"
if old not in s:
    raise SystemExit("Expected ComfyUI_essentials Session constructor not found")
p.write_text(s.replace(old, new, 1))
print("Patched ComfyUI_essentials: force transparent_background to CPU (jit off).")
PY

rm -rf ComfyUI-Hunyuan3DWrapper
git clone --depth 1 https://github.com/kijai/ComfyUI-Hunyuan3DWrapper.git ComfyUI-Hunyuan3DWrapper
cd ComfyUI-Hunyuan3DWrapper
pip install --no-cache-dir -r requirements.txt
pip install --no-cache-dir rembg omegaconf timm

# Build and install the custom rasterizer module (CUDAExtension — needs nvcc at image build time).
if [ -z "${CUDA_HOME:-}" ] && [ -d "/usr/local/cuda" ]; then
  export CUDA_HOME="/usr/local/cuda"
fi
if command -v nvcc >/dev/null 2>&1 && [ -n "${CUDA_HOME:-}" ]; then
  # Use setuptools directly (upstream docs). Pip wheel builds can hide nvcc/ninja errors on CI.
  export MAX_JOBS="${MAX_JOBS:-2}"
  export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-7.0;7.5;8.0;8.6;8.9;9.0+PTX}"
  (cd hy3dgen/texgen/custom_rasterizer && python setup.py install)
else
  echo "CUDA not found (nvcc/CUDA_HOME). Skipping custom_rasterizer build."
fi

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
