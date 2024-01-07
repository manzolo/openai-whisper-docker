# OpenAI Whisper Docker Image (GPU Accelerated)

This Docker image provides a convenient environment for running OpenAI Whisper, a powerful automatic speech recognition (ASR) system. It is based on the latest Ubuntu image and includes the necessary dependencies for running Whisper seamlessly.

## Usage
To build the Docker image, use the following command:

```bash
docker build -t openai-whisper .
```

## Running OpenAI Whisper
To run OpenAI Whisper with the Docker image, you can use the following example command:

```bash
docker run --gpus all -it -v ${PWD}/models:/root/.cache/whisper -v ${PWD}/audio-files:/app openai-whisper whisper M13.mp3 --device cuda --model large-v3 --language Italian --output_dir /app --output_format txt
```

This command utilizes GPU acceleration (--gpus all), mounts the local directories for Whisper models and audio files, and specifies the input audio file, output directory, language, and other relevant parameters.

### Additional Commands
You can also check the GPU information using the following command:

```bash
docker run --gpus all -it openai-whisper nvidia-smi
```
## References
[OpenAI Whisper GitHub Repository](https://github.com/openai/whisper)

[NVIDIA Container Toolkit Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

Feel free to explore and adapt this Docker image based on your specific use case and requirements. For more details on OpenAI Whisper and its usage, refer to the official documentation.