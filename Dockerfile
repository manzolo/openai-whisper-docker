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
