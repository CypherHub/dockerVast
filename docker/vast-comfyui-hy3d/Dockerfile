# ComfyBasic + ComfyUI-Hunyuan3DWrapper + baked Hunyuan3D DiT weights.
# On Vast use: bash /usr/local/bin/vast-onstart-comfyui-hy3d.sh
# GHCR: ghcr.io/<OWNER>/vast-comfyui-hy3d
FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HUB_DISABLE_PROGRESS_BARS=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential cmake pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libgomp1 libopengl0 \
    ffmpeg libavcodec-dev libavformat-dev libavutil-dev \
    net-tools cron nano wget openssh-server \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /root/.ssh && chmod 700 /root/.ssh

COPY pin-torch27.sh /usr/local/bin/pin-torch27.sh
RUN chmod +x /usr/local/bin/pin-torch27.sh

WORKDIR /opt
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

COPY install-hy3d.sh /tmp/install-hy3d.sh
COPY patch_hy3dshape_pipelines.py /tmp/patch_hy3dshape_pipelines.py
RUN chmod +x /tmp/install-hy3d.sh \
    && cd /opt/ComfyUI && . venv/bin/activate \
    && bash /tmp/install-hy3d.sh \
    && /usr/local/bin/pin-torch27.sh \
    && rm -f /tmp/install-hy3d.sh /tmp/patch_hy3dshape_pipelines.py

# Hy3D-only: no PlusTrellis on-start script and no Trellis2 first-boot installer (see vast-onstart-comfyui-hy3d.sh).
COPY vast-onstart-comfyui-hy3d.sh /usr/local/bin/vast-onstart-comfyui-hy3d.sh
RUN chmod +x /usr/local/bin/vast-onstart-comfyui-hy3d.sh

WORKDIR /opt/ComfyUI
EXPOSE 8188
