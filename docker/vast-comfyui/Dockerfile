# GHCR image for Vast.ai: PyTorch CUDA + ComfyUI + custom nodes (see README for template).
# Build: docker build -t ghcr.io/<OWNER>/vast-comfyui:latest .
FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential libgl1 libglib2.0-0 \
    net-tools cron nano wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI \
    && cd ComfyUI \
    && python -m venv venv --system-site-packages \
    && . venv/bin/activate \
    && pip install -U pip setuptools wheel \
    && pip install -r requirements.txt

COPY install-nodes.sh /tmp/install-nodes.sh
RUN chmod +x /tmp/install-nodes.sh \
    && cd /opt/ComfyUI && . venv/bin/activate && bash /tmp/install-nodes.sh \
    && rm /tmp/install-nodes.sh

COPY vast-onstart-comfyui.sh /usr/local/bin/vast-onstart-comfyui.sh
RUN chmod +x /usr/local/bin/vast-onstart-comfyui.sh

WORKDIR /opt/ComfyUI
EXPOSE 8188
