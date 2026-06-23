# OpenAI Whisper Docker Image (GPU Accelerated)

<a href="https://www.buymeacoffee.com/manzolo">
  <img src=".github/blue-button.png" alt="Buy Me A Coffee" width="200">
</a>

> **Disclaimer:** This is an unofficial, community-maintained Docker wrapper around [OpenAI Whisper](https://github.com/openai/whisper). It is not affiliated with or endorsed by OpenAI. This project is maintained as a personal hobby — use it as-is, no support is guaranteed.

This Docker image provides a convenient environment for running [OpenAI Whisper](https://github.com/openai/whisper), a powerful automatic speech recognition (ASR) system. Based on Ubuntu 24.04 with Python 3.12 and all necessary dependencies included.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)

## Quick Start

1. Place your audio files in the `audio-files/` directory
2. Run the transcription (see examples below)
3. Find the output in the same `audio-files/` directory

### macOS batch script

Use the helper script to scan `audio-files/` automatically:

```bash
./transcribe-audio-files.sh
```

Defaults:
- language: `Russian`
- model: `small`
- output: `.txt` files next to the source file in `audio-files/`
- parallel jobs: value of `default_max_parallel` / `$defaultMaxParallel` in the script

To override the defaults:

```bash
MODEL=small LANGUAGE=Russian ./transcribe-audio-files.sh
```

To run multiple files at once without editing the script:

```bash
MODEL=turbo LANGUAGE=Russian MAX_PARALLEL=2 ./transcribe-audio-files.sh
```

The script skips files that already have a matching `.txt` transcript next to them. It also creates temporary `.whisper-lock` directories while a file is being processed to avoid duplicate work across concurrent runs.

### Windows 11 batch script

Use the PowerShell helper to scan `audio-files/` automatically:

```powershell
.\transcribe-audio-files.ps1
```

Defaults:
- language: `Russian`
- model: `small`
- output: `.txt` files next to the source file in `audio-files/`
- parallel jobs: value of `default_max_parallel` / `$defaultMaxParallel` in the script

This matches the macOS script.

To override the defaults:

```powershell
$env:MODEL="small"; $env:LANGUAGE="Russian"; .\transcribe-audio-files.ps1
```

To run multiple files at once without editing the script:

```powershell
$env:MODEL="turbo"; $env:LANGUAGE="Russian"; $env:MAX_PARALLEL="2"; .\transcribe-audio-files.ps1
```

The script skips files that already have a matching `.txt` transcript next to them. It also creates temporary `.whisper-lock` directories while a file is being processed to avoid duplicate work across concurrent runs.
