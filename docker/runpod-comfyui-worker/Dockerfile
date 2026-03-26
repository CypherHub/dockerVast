FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    COMFYUI_DIR=/opt/ComfyUI \
    COMFYUI_HOST=127.0.0.1 \
    COMFYUI_PORT=8188 \
    COMFYUI_MAX_WAIT_SEC=900

RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential cmake pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libgomp1 \
    ffmpeg libavcodec-dev libavformat-dev libavutil-dev \
    curl wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git ComfyUI \
    && cd ComfyUI \
    && python -m venv venv --system-site-packages \
    && . venv/bin/activate \
    && pip install -U pip setuptools wheel \
    && pip install --no-cache-dir \
         "torch==2.7.0" "torchvision==0.22.0" "torchaudio==2.7.0" \
         --index-url https://download.pytorch.org/whl/cu128 \
         --extra-index-url https://pypi.org/simple \
    && sed '/^torch$/d; /^torchvision$/d; /^torchaudio$/d' requirements.txt > /tmp/r.txt \
    && pip install --no-cache-dir -r /tmp/r.txt

COPY install-nodes.sh /tmp/install-nodes.sh
RUN chmod +x /tmp/install-nodes.sh \
    && cd /opt/ComfyUI && . venv/bin/activate \
    && bash /tmp/install-nodes.sh \
    && rm /tmp/install-nodes.sh

COPY start-comfyui.sh /usr/local/bin/start-comfyui.sh
COPY worker.py /app/worker.py

RUN chmod +x /usr/local/bin/start-comfyui.sh \
    && /opt/ComfyUI/venv/bin/pip install --no-cache-dir runpod requests

WORKDIR /app
EXPOSE 8188

CMD bash -lc "/usr/local/bin/start-comfyui.sh && /opt/ComfyUI/venv/bin/python /app/worker.py"
