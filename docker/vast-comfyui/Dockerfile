# Vast.ai + ComfyUI + ReActor + ComfyUI-Trellis2 (Trellis.2) + DINOv3 weights baked in.
# PyTorch 2.7 / CUDA 12.8 + cp312 Trellis Linux wheels. Workflows run after pull + on-start.
# Build: docker build -t ghcr.io/<OWNER>/vast-comfyui:latest .
FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HUB_DISABLE_PROGRESS_BARS=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential cmake pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libgomp1 \
    ffmpeg libavcodec-dev libavformat-dev libavutil-dev \
    net-tools cron nano wget \
    && rm -rf /var/lib/apt/lists/*

COPY pin-torch27.sh /usr/local/bin/pin-torch27.sh
RUN chmod +x /usr/local/bin/pin-torch27.sh

WORKDIR /opt
# venv inherits conda PyTorch 2.7; we re-pin after pip stages so Trellis cumesh stays ABI-matched.
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI \
    && cd ComfyUI \
    && python -m venv venv --system-site-packages \
    && . venv/bin/activate \
    && pip install -U pip setuptools wheel huggingface_hub \
    && pip install --no-cache-dir \
         'torch==2.7.0' 'torchvision==0.22.0' 'torchaudio==2.7.0' \
         --index-url https://download.pytorch.org/whl/cu128 \
         --extra-index-url https://pypi.org/simple \
    && sed '/^torch$/d; /^torchvision$/d; /^torchaudio$/d' requirements.txt > /tmp/r.txt \
    && pip install --no-cache-dir -r /tmp/r.txt \
    && /usr/local/bin/pin-torch27.sh

COPY install-nodes.sh /tmp/install-nodes.sh
RUN chmod +x /tmp/install-nodes.sh \
    && cd /opt/ComfyUI && . venv/bin/activate \
    && bash /tmp/install-nodes.sh \
    && /usr/local/bin/pin-torch27.sh \
    && rm /tmp/install-nodes.sh

COPY install-trellis2.sh /tmp/install-trellis2.sh
RUN chmod +x /tmp/install-trellis2.sh \
    && cd /opt/ComfyUI && . venv/bin/activate \
    && bash /tmp/install-trellis2.sh \
    && /usr/local/bin/pin-torch27.sh \
    && rm /tmp/install-trellis2.sh

# DINOv3 is ~GB; HF in CI is flaky/slow — on-start downloads once to /workspace (see vast-onstart-comfyui.sh).

COPY vast-onstart-comfyui.sh /usr/local/bin/vast-onstart-comfyui.sh
RUN chmod +x /usr/local/bin/vast-onstart-comfyui.sh

WORKDIR /opt/ComfyUI
EXPOSE 8188
