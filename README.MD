# OpenAI Whisper Docker Image (GPU Accelerated)

<a href="https://www.buymeacoffee.com/manzolo">
  <img src=".github/blue-button.png" alt="Buy Me A Coffee" width="200">
</a>

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

To override the defaults:

```bash
MODEL=small LANGUAGE=Russian ./transcribe-audio-files.sh
```

The script skips files that already have a matching `.txt` transcript next to them.

### Windows 11 batch script

Use the PowerShell helper to scan `audio-files/` automatically:

```powershell
.\transcribe-audio-files.ps1
```

Defaults:
- language: `Russian`
- model: `small`
- output: `.txt` files next to the source file in `audio-files/`

This matches the macOS script.

To override the defaults:

```powershell
$env:MODEL="small"; $env:LANGUAGE="Russian"; .\transcribe-audio-files.ps1
```

The script skips files that already have a matching `.txt` transcript next to them.
