# Backlog

## Miglioramenti pianificati

Dalla review del progetto del 2026-07-05. Fatti (in attesa di commit/push): LICENSE MIT, pin `openai-whisper==20250625` + label OCI nel Dockerfile, publish automatico su GHCR (`ghcr.io/manzolo/openai-whisper-docker`, tag `latest` + data) nel workflow CI.

### Priorità media
- [x] Variante immagine CPU-only: `ARG TORCH_VARIANT=cpu` (torch da `https://download.pytorch.org/whl/cpu`) → immagine da ~13 GB a ~3,5 GB, tag `:cpu` e `:cpu-<data>` su GHCR — fatto 2026-07-05
- [x] Test end-to-end in CI: trascrizione reale con modello `tiny` su audio parlato generato con espeak-ng, su entrambe le immagini (default e cpu) — fatto 2026-07-05
- [ ] Smoke test dell'immagine pubblicata: step (o job) post-publish che fa `docker pull ghcr.io/manzolo/openai-whisper-docker:latest` e verifica `whisper --help`, così da validare esattamente ciò che gli utenti scaricano (manifest, label, push andato a buon fine) e non solo la build locale
- [ ] Output come non-root: `user: "${UID}:${GID}"` nel compose (spostando la cache modelli fuori da `/root/.cache/whisper`) — oggi le trascrizioni in `audio-files/` appartengono a root sull'host

### Priorità bassa
- [ ] `ENTRYPOINT ["whisper"]` al posto di `CMD` per non ripetere `whisper` nei comandi (breaking change: aggiornare README/CLAUDE.md insieme)
- [ ] Rimuovere `python3-venv` dal Dockerfile (installato ma mai usato) oppure usare un venv vero al posto di `--break-system-packages`
- [ ] Deduplicare README/CLAUDE.md: README come fonte di verità, CLAUDE.md più snello

## In attesa di risposta autore

### PR #4 — "Add start time" (LightVolk, branch `add-start-time`) — arrivata 2026-06-23
Aggiunge script di batch transcription (`transcribe-audio-files.sh` + `.ps1`), rinomina `CLAUDE.md`→`AGENTS.md`, riscrive il README, committa file `.idea/`.

Review con commenti inline pubblicata il 2026-06-23: https://github.com/manzolo/openai-whisper-docker/pull/4#pullrequestreview-4555987029

**Stato:** rilievi lasciati sulla PR + suggestion applicabili per i due blocker (review 4556028927). Aspettiamo che l'autore le applichi/risponda. Punti aperti:
- [ ] Bug: skip "già trascritto" hardcodato su `.txt`, ignora `OUTPUT_FORMAT` (sia `.sh` che `.ps1`) — **blocker** — suggestion inviata
- [ ] Bug: PowerShell `Wait-Job` chiamato con `$null` → crash quando tutti i file in coda sono lockati — **blocker** — suggestion inviata
- [ ] Robustezza: PowerShell senza cleanup dei lock all'interruzione (bash ha `trap`)
- [ ] Efficienza: probe ffprobe seriale e anticipato su tutti i file
- [ ] Cleanup: file `.idea/*` committati e contemporaneamente in `.gitignore`
- [ ] Scope/docs: rename `CLAUDE.md`→`AGENTS.md` e riscrittura README (perde sezione Docker Compose, GPU/NVIDIA, tabella modelli) fuori scope per il titolo; descrizione PR vuota
