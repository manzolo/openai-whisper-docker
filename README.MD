# OpenAI Whisper Docker Image (GPU Accelerated)

This Docker image provides a convenient environment for running OpenAI Whisper, a powerful automatic speech recognition (ASR) system. It is based on the latest Ubuntu image and includes the necessary dependencies for running Whisper seamlessly.

## Prerequisites

Before you can use this Docker image, you need to have Docker installed on your system.

### Installing Docker

Follow the instructions on the [official Docker website](https://docs.docker.com/get-docker/) to install Docker for your operating system.

## Usage
To build the Docker image, use the following command:

```bash
docker build -t openai-whisper .
```

## Running OpenAI Whisper (GPU)
To run OpenAI Whisper with the Docker image, you can use the following example command:

```bash
docker run --gpus all -it -v ${PWD}/models:/root/.cache/whisper -v ${PWD}/audio-files:/app openai-whisper whisper audio-file.mp3 --device cuda --model turbo --language Italian --output_dir /app --output_format txt
```

This command utilizes GPU acceleration (--gpus all), mounts the local directories for Whisper models and audio files, and specifies the input audio file, output directory, language, and other relevant parameters.

### Choosing the Right Model  

Whisper supports multiple models with varying resource requirements and performance levels.  

- **`large-v3`**:  
  The most accurate model, but it requires substantial VRAM (10–15 GB). Recommended for powerful GPUs with sufficient memory.  

- **`turbo`**:  
  A more memory-efficient alternative to `large-v3`, offering near-comparable accuracy. This is suitable for GPUs with limited VRAM (e.g., 8 GB VRAM).  

## Running OpenAI Whisper (CPU)

If you do not have a GPU or want to run without GPU acceleration, you can omit the --gpus all flag from the command. For example:
```bash
docker run -it -v ${PWD}/models:/root/.cache/whisper -v ${PWD}/audio-files:/app openai-whisper whisper audio-file.mp3 --model turbo --language Italian --output_dir /app --output_format txt
```

### Additional Commands
You can also check the GPU information using the following command:

```bash
docker run --gpus all -it openai-whisper nvidia-smi
```
## References
- [OpenAI Whisper GitHub Repository](https://github.com/openai/whisper)

- [NVIDIA Container Toolkit Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

- [Docker Official Website](https://docs.docker.com/get-docker/)

Feel free to explore and adapt this Docker image based on your specific use case and requirements. For more details on OpenAI Whisper and its usage, refer to the official documentation.
