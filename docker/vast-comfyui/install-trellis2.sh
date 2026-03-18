#!/usr/bin/env bash
# ComfyUI-Trellis2 — Linux Torch270 wheels (cp312 + PyTorch 2.7).
set -euo pipefail
cd /opt/ComfyUI/custom_nodes
rm -rf ComfyUI-Trellis2
git clone --depth 1 https://github.com/visualbruno/ComfyUI-Trellis2.git ComfyUI-Trellis2

cd /opt/ComfyUI
# shellcheck source=/dev/null
source venv/bin/activate

WDIR="/opt/ComfyUI/custom_nodes/ComfyUI-Trellis2/wheels/Linux/Torch270"
shopt -s nullglob
for f in "$WDIR"/cumesh-*.whl "$WDIR"/nvdiffrast-*.whl "$WDIR"/nvdiffrec_render-*.whl \
         "$WDIR"/flex_gemm-*.whl "$WDIR"/o_voxel-*.whl; do
  [[ -f "$f" ]] || continue
  echo "[install-trellis2] pip install $(basename "$f")"
  pip install "$f"
done
shopt -u nullglob

pip install --no-cache-dir -r custom_nodes/ComfyUI-Trellis2/requirements.txt
# Import check omitted: some wheels need GPU at runtime; build hosts are CPU-only.
