# GHCR image for Vast.ai: PyTorch CUDA + ComfyUI + custom nodes (see README for template).
# PyTorch 2.7+ required for ComfyUI-Trellis2 Linux wheels (Torch270 / cp312).
# Build: docker build -t ghcr.io/<OWNER>/vast-comfyui:latest .
FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential libgl1 libglib2.0-0 \
    net-tools cron nano wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
# Install ComfyUI deps first, then force Torch 2.7.x to match Trellis2 prebuilt Linux wheels (pip would pull 2.8+).
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI \
    && cd ComfyUI \
    && python -m venv venv --system-site-packages \
    && . venv/bin/activate \
    && pip install -U pip setuptools wheel \
    && pip install -r requirements.txt \
    && pip install --force-reinstall --no-cache-dir \
         'torch==2.7.0' 'torchvision==0.22.0' 'torchaudio==2.7.0' \
         --index-url https://download.pytorch.org/whl/cu128

COPY install-nodes.sh /tmp/install-nodes.sh
COPY install-trellis2.sh /tmp/install-trellis2.sh
RUN chmod +x /tmp/install-nodes.sh /tmp/install-trellis2.sh \
    && cd /opt/ComfyUI && . venv/bin/activate && bash /tmp/install-nodes.sh \
    && bash /tmp/install-trellis2.sh \
    && rm /tmp/install-nodes.sh /tmp/install-trellis2.sh

COPY vast-onstart-comfyui.sh /usr/local/bin/vast-onstart-comfyui.sh
RUN chmod +x /usr/local/bin/vast-onstart-comfyui.sh

WORKDIR /opt/ComfyUI
EXPOSE 8188
