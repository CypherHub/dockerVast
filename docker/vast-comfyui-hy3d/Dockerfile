# Hy3D = published vast-comfyui-basic + ComfyUI-Hunyuan3DWrapper + baked weights.
# Base must exist in GHCR (build basic first, or use :latest from a prior push).
# Vast: many templates run `vast-onstart-comfyui.sh` — we symlink that to the Hy3D on-start.
ARG VAST_BASE_IMAGE=ghcr.io/cypherhub/vast-comfyui-basic:latest
FROM ${VAST_BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# PyTorch *runtime* base has CUDA libs but not nvcc — required to compile Hunyuan3D custom_rasterizer at build time.
RUN apt-get update && apt-get install -y --no-install-recommends wget gnupg \
    libopengl0 curl ca-certificates \
    && wget -qO /tmp/cuda-keyring.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i /tmp/cuda-keyring.deb && rm -f /tmp/cuda-keyring.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends cuda-toolkit-12-8 \
    && rm -rf /var/lib/apt/lists/*

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=/usr/local/cuda/bin:${PATH}

COPY install-hy3d.sh /tmp/install-hy3d.sh
COPY patch_hy3dshape_pipelines.py /tmp/patch_hy3dshape_pipelines.py
RUN chmod +x /tmp/install-hy3d.sh \
    && cd /opt/ComfyUI && . venv/bin/activate \
    && bash /tmp/install-hy3d.sh \
    && /usr/local/bin/pin-torch27.sh \
    && rm -f /tmp/install-hy3d.sh /tmp/patch_hy3dshape_pipelines.py

COPY vast-onstart-comfyui-hy3d.sh /usr/local/bin/vast-onstart-comfyui-hy3d.sh
RUN chmod +x /usr/local/bin/vast-onstart-comfyui-hy3d.sh \
    && ln -sf /usr/local/bin/vast-onstart-comfyui-hy3d.sh /usr/local/bin/vast-onstart-comfyui.sh

WORKDIR /opt/ComfyUI
EXPOSE 8188
