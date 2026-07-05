FROM ubuntu:24.04

ARG WHISPER_VERSION=20250625
# Set to "cpu" to install CPU-only PyTorch wheels (~3.5 GB image instead of ~13 GB)
ARG TORCH_VARIANT=cuda

LABEL org.opencontainers.image.title="openai-whisper-docker" \
      org.opencontainers.image.description="Unofficial Docker image for OpenAI Whisper ASR. Not affiliated with or endorsed by OpenAI." \
      org.opencontainers.image.source="https://github.com/manzolo/openai-whisper-docker" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    ffmpeg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$TORCH_VARIANT" = "cpu" ]; then \
      pip install --break-system-packages torch --index-url https://download.pytorch.org/whl/cpu; \
    fi

RUN pip install --break-system-packages openai-whisper==${WHISPER_VERSION}

WORKDIR /app

CMD ["whisper"]
