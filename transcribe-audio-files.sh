#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input_dir="${INPUT_DIR:-"$script_dir/audio-files"}"
model_cache_dir="${MODEL_CACHE_DIR:-"$script_dir/models"}"
image_name="${IMAGE_NAME:-openai-whisper}"
model="${MODEL:-small}"
language="${LANGUAGE:-Russian}"
output_format="${OUTPUT_FORMAT:-txt}"

supported_extensions=(
  mp3
  m4a
  wav
  flac
  ogg
  mp4
  mov
  mkv
  webm
  aac
  opus
  wma
  alac
  3gp
)

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found in PATH" >&2
  exit 1
fi

if [[ ! -d "$input_dir" ]]; then
  echo "Input directory not found: $input_dir" >&2
  exit 1
fi

mkdir -p "$model_cache_dir"

echo "Input directory: $input_dir"
echo "Model cache: $model_cache_dir"
echo "Whisper model: $model"
if [[ -n "$language" ]]; then
  echo "Language: $language"
else
  echo "Language: auto-detect"
fi
echo "Output format: $output_format"

if ! docker image inspect "$image_name" >/dev/null 2>&1; then
  echo "Building Docker image: $image_name"
  docker build -t "$image_name" "$script_dir"
fi

files=()
find_expr=()
for ext in "${supported_extensions[@]}"; do
  if [[ ${#find_expr[@]} -gt 0 ]]; then
    find_expr+=( -o )
  fi
  find_expr+=( -iname "*.${ext}" )
done

while IFS= read -r -d '' input_file; do
  files+=( "$input_file" )
done < <(
  find "$input_dir" -maxdepth 1 -type f \( "${find_expr[@]}" \) -print0
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No supported audio/video files found in: $input_dir"
  exit 0
fi

processed=0
skipped=0
started_at="${SECONDS}"

human_duration() {
  local total_seconds="$1"
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

for input_file in "${files[@]}"; do
  [[ -f "$input_file" ]] || continue

  base_name="$(basename "$input_file")"
  stem="${base_name%.*}"
  transcript_path="$input_dir/$stem.txt"

  if [[ -f "$transcript_path" ]]; then
    echo "Skipping $base_name because $stem.txt already exists"
    skipped=$((skipped + 1))
    continue
  fi

  file_started_at="${SECONDS}"
  echo "[$((processed + skipped + 1))/${#files[@]}] Transcribing $base_name"
  whisper_args=(whisper "/app/$base_name" --model "$model" --output_dir /app --output_format "$output_format")
  if [[ -n "$language" ]]; then
    whisper_args+=(--language "$language")
  fi

  docker run --rm \
    -v "$model_cache_dir:/root/.cache/whisper" \
    -v "$input_dir:/app" \
    "$image_name" "${whisper_args[@]}"

  file_elapsed=$((SECONDS - file_started_at))
  echo "Finished $base_name in $(human_duration "$file_elapsed")"
  processed=$((processed + 1))
done

total_elapsed=$((SECONDS - started_at))
total_duration="$(human_duration "$total_elapsed")"
echo "Done. Processed: $processed, skipped: $skipped, total time: $total_duration"
