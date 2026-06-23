# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Containerized deployment of OpenAI's Whisper automatic speech recognition (ASR) system. Provides both GPU and CPU execution modes through Docker and Docker Compose, based on Ubuntu 24.04 with Python 3.12.

## Build Commands

```bash
# Build Docker image
docker build -t openai-whisper .

# Build with Docker Compose (CPU profile)
docker compose --profile cpu build
```

## Running Whisper

**GPU Mode (requires NVIDIA GPU + Container Toolkit):**
```bash
docker compose run --rm whisper-gpu whisper audio-file.mp3 --device cuda --model turbo --language Italian --output_dir /app --output_format txt
```

**CPU Mode:**
```bash
docker compose run --rm whisper-cpu whisper audio-file.mp3 --model turbo --language Italian --output_dir /app --output_format txt
```

**Direct Docker (GPU):**
```bash
docker run --gpus all -v ./models:/root/.cache/whisper -v ./audio-files:/app openai-whisper whisper audio-file.mp3 --device cuda --model turbo
```

## Architecture

- **Dockerfile**: Ubuntu 24.04 base with Python 3, pip, ffmpeg, and openai-whisper package
- **docker-compose.yml**: Two service profiles (`gpu` and `cpu`) with identical volume mappings
- **Volume mounts**:
  - `./models` → `/root/.cache/whisper` (model cache persistence)
  - `./audio-files` → `/app` (working directory for input/output)

## Model Options

- `large-v3`: Most accurate, requires 10-15 GB VRAM
- `turbo` (large-v3-turbo): Memory-efficient, requires ~8 GB VRAM

## CI/CD

GitHub Actions workflow (`.github/workflows/docker-build-test.yml`) runs on pushes/PRs to main:
- Builds Docker image
- Verifies whisper, ffmpeg, and Python installations
- Builds Docker Compose CPU profile
