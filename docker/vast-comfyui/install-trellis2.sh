#!/usr/bin/env bash
# ComfyUI-Trellis2 (https://github.com/visualbruno/ComfyUI-Trellis2) — Linux wheels match Torch 2.7 + cp312.
set -euo pipefail
cd /opt/ComfyUI/custom_nodes
rm -rf ComfyUI-Trellis2
git clone --depth 1 https://github.com/visualbruno/ComfyUI-Trellis2.git ComfyUI-Trellis2

cd /opt/ComfyUI
# shellcheck source=/dev/null
source venv/bin/activate

WDIR="/opt/ComfyUI/custom_nodes/ComfyUI-Trellis2/wheels/Linux/Torch270"
if [[ ! -d "$WDIR" ]]; then
  echo "ComfyUI-Trellis2: missing $WDIR" >&2
  exit 1
fi

# Same order as upstream README (nvdiffrec_render not shipped for Linux/Torch270 — skip if absent).
shopt -s nullglob
for pattern in \
  "$WDIR"/cumesh-*.whl \
  "$WDIR"/nvdiffrast-*.whl \
  "$WDIR"/nvdiffrec_render-*.whl \
  "$WDIR"/flex_gemm-*.whl \
  "$WDIR"/o_voxel-*.whl; do
  [[ -f "$pattern" ]] || continue
  echo "[install-trellis2] pip install $(basename "$pattern")"
  pip install "$pattern"
done
shopt -u nullglob

pip install -r custom_nodes/ComfyUI-Trellis2/requirements.txt
