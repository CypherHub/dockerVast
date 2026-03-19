#!/usr/bin/env bash
# Run on Vast first boot (not in GHCR): meshlib/cumesh pip often fails on GitHub runners.
set -euo pipefail
cd /opt/ComfyUI
# shellcheck source=/dev/null
source venv/bin/activate
[[ -x /usr/local/bin/pin-torch27.sh ]] && /usr/local/bin/pin-torch27.sh

cd custom_nodes
rm -rf ComfyUI-Trellis2
git clone --depth 1 https://github.com/visualbruno/ComfyUI-Trellis2.git ComfyUI-Trellis2

WDIR="/opt/ComfyUI/custom_nodes/ComfyUI-Trellis2/wheels/Linux/Torch270"
shopt -s nullglob
for f in "$WDIR"/cumesh-*.whl "$WDIR"/nvdiffrast-*.whl "$WDIR"/nvdiffrec_render-*.whl \
         "$WDIR"/flex_gemm-*.whl "$WDIR"/o_voxel-*.whl; do
  [[ -f "$f" ]] || continue
  echo "[trellis2-runtime] pip install $(basename "$f")"
  pip install --no-cache-dir "$f"
done
shopt -u nullglob

pip install --no-cache-dir -r /opt/ComfyUI/custom_nodes/ComfyUI-Trellis2/requirements.txt
[[ -x /usr/local/bin/pin-torch27.sh ]] && /usr/local/bin/pin-torch27.sh
echo "[trellis2-runtime] done"
