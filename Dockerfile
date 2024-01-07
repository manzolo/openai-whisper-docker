# Usa l'immagine di base di Ubuntu
FROM ubuntu:latest

# Aggiorna il sistema e installa le dipendenze necessarie
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    python3.9 \
    python3-distutils \
    python3-pip \
    ffmpeg

# Aggiorna pip
RUN pip install --upgrade pip

# Installa openai-whisper
RUN pip install -U openai-whisper

# Imposta il working directory nel container
WORKDIR /app

# Comando di default quando il container viene avviato
CMD ["whisper"]

#https://github.com/openai/whisper
#https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
#docker build -t openai-whisper .
#docker run --gpus all -it -v ${PWD}/models:/root/.cache/whisper -v ${PWD}/audio-files:/app openai-whisper whisper M13.mp3 --device cuda --model large-v3 --language Italian --output_dir /app --output_format txt
#docker run --gpus all -it openai-whisper nvidia-smi


