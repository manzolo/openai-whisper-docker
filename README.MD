# OpenAI Whisper Docker Image (GPU Accelerated)

<a href="https://www.buymeacoffee.com/manzolo">
  <img src=".github/blue-button.png" alt="Buy Me A Coffee" width="200">
</a>

> **Disclaimer:** This is an unofficial, community-maintained Docker wrapper around [OpenAI Whisper](https://github.com/openai/whisper). It is not affiliated with or endorsed by OpenAI. This project is maintained as a personal hobby — use it as-is, no support is guaranteed.

This Docker image provides a convenient environment for running [OpenAI Whisper](https://github.com/openai/whisper), a powerful automatic speech recognition (ASR) system. Based on Ubuntu 24.04 with Python 3.12 and all necessary dependencies included.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) (for GPU mode only)

## Quick Start

1. Place your audio files in the `audio-files/` directory
2. Run the transcription (see examples below)
3. Find the output in the same `audio-files/` directory

> **Note:** the first run takes a while: Whisper downloads the selected model (~1.6 GB for `turbo`, ~3 GB for `large-v3`) into the `models/` directory before transcribing. Subsequent runs reuse the cached model and start right away.

## Usage

### Prebuilt Image

A prebuilt image is published to GitHub Container Registry on every push to `main` and rebuilt monthly:

```bash
docker pull ghcr.io/manzolo/openai-whisper-docker:latest
```

If you only run on CPU, pull the much smaller CPU-only variant (~3.5 GB instead of ~13 GB, PyTorch without CUDA):

```bash
docker pull ghcr.io/manzolo/openai-whisper-docker:cpu
```

Date-stamped tags (e.g. `:20260705`, `:cpu-20260705`) are also available if you want to pin a specific build.

### Docker Compose (Recommended)

**Build:**
```bash
docker compose --profile gpu build
```

**GPU mode:**
```bash
docker compose run --rm whisper-gpu whisper audio-file.mp3 --device cuda --model turbo --language Italian --output_dir /app --output_format txt
```

**CPU mode:**
```bash
docker compose run --rm whisper-cpu whisper audio-file.mp3 --model turbo --language Italian --output_dir /app --output_format txt
```

### Docker Direct

**Build:**
```bash
docker build -t openai-whisper .
```

**GPU mode:**
```bash
docker run --gpus all -it -v ${PWD}/models:/root/.cache/whisper -v ${PWD}/audio-files:/app openai-whisper whisper audio-file.mp3 --device cuda --model turbo --language Italian --output_dir /app --output_format txt
```

**CPU mode:**
```bash
docker run -it -v ${PWD}/models:/root/.cache/whisper -v ${PWD}/audio-files:/app openai-whisper whisper audio-file.mp3 --model turbo --language Italian --output_dir /app --output_format txt
```

## Volume Mounts

| Local Path | Container Path | Description |
|------------|----------------|-------------|
| `./models` | `/root/.cache/whisper` | Cached Whisper models (persisted between runs) |
| `./audio-files` | `/app` | Input audio files and output transcriptions |

## Models

| Model | VRAM Required | Description |
|-------|---------------|-------------|
| `large-v3` | 10-15 GB | Most accurate, recommended for powerful GPUs |
| `turbo` | ~8 GB | Memory-efficient, near-comparable accuracy |

## Useful Commands

Check GPU information:
```bash
docker run --gpus all -it openai-whisper nvidia-smi
```

## License

This project is licensed under the [MIT License](LICENSE). The image bundles third-party software under its own licenses: [OpenAI Whisper](https://github.com/openai/whisper) (MIT), PyTorch (BSD-3), ffmpeg (from Ubuntu packages, LGPL/GPL), and Ubuntu.

## References

- [OpenAI Whisper GitHub Repository](https://github.com/openai/whisper)
- [NVIDIA Container Toolkit Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Docker Official Website](https://docs.docker.com/get-docker/)

---

## 🧠 Local AI Lab

This project is part of **[manzolo's Local AI Lab](https://github.com/manzolo/local-ai-lab)** — a family of self-hosted AI projects (LLM, voice, vision & documents) that share the same conventions and can be wired together through the shared `local-ai-net` Docker network.

Explore the whole family: [`topic:local-ai`](https://github.com/search?q=user%3Amanzolo+topic%3Alocal-ai&type=repositories)
