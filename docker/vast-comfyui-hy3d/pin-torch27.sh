#!/usr/bin/env bash
# Keep PyTorch 2.7.x (Trellis cumesh wheels) after other pip installs upgraded torch.
set -euo pipefail
# shellcheck source=/dev/null
source /opt/ComfyUI/venv/bin/activate
pip install --force-reinstall --no-cache-dir \
  'torch==2.7.0' 'torchvision==0.22.0' 'torchaudio==2.7.0' \
  --index-url https://download.pytorch.org/whl/cu128 \
  --extra-index-url https://pypi.org/simple
python -c "import torch; assert torch.__version__.startswith('2.7'), torch.__version__; print('[pin-torch27]', torch.__version__)"
