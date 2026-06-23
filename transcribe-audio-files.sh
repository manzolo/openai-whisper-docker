#!/usr/bin/env bash

set -euo pipefail

script_started_epoch="$(date +%s)"
script_started_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input_dir="${INPUT_DIR:-"$script_dir/audio-files"}"
model_cache_dir="${MODEL_CACHE_DIR:-"$script_dir/models"}"
default_max_parallel=1
image_name="${IMAGE_NAME:-openai-whisper}"
model="${MODEL:-small}"
language="${LANGUAGE:-Russian}"
output_format="${OUTPUT_FORMAT:-txt}"
max_parallel="${MAX_PARALLEL:-$default_max_parallel}"

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

if ! [[ "$max_parallel" =~ ^[1-9][0-9]*$ ]]; then
  echo "MAX_PARALLEL must be a positive integer" >&2
  exit 1
fi

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
echo "Max parallel jobs: $max_parallel"
echo "Script started at: $script_started_at"

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
  script_finished_epoch="$(date +%s)"
  script_finished_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
  total_elapsed=$((script_finished_epoch - script_started_epoch))
  total_duration="$(printf '%02d:%02d:%02d' "$((total_elapsed / 3600))" "$(((total_elapsed % 3600) / 60))" "$((total_elapsed % 60))")"
  echo "Script finished at: $script_finished_at"
  echo "Done. Processed: 0, skipped: 0, total runtime: $total_duration"
  exit 0
fi

processed=0
skipped=0
failed=0
pending_base_names=()
pending_lock_dirs=()
pending_display_indexes=()
pending_duration_labels=()
active_pids=()
active_result_files=()

cleanup_paths=()

human_duration() {
  local total_seconds="$1"
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))
  printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

get_media_duration_label() {
  local base_name="$1"
  local duration_output duration_seconds

  duration_output="$(
    docker run --rm \
      -v "$input_dir:/app" \
      "$image_name" \
      ffprobe \
      -v error \
      -show_entries format=duration \
      -of default=noprint_wrappers=1:nokey=1 \
      "/app/$base_name" 2>/dev/null || true
  )"

  duration_output="${duration_output//$'\r'/}"
  duration_output="${duration_output//$'\n'/}"
  if [[ -z "$duration_output" ]]; then
    echo "unknown"
    return
  fi

  duration_seconds="${duration_output%.*}"
  if ! [[ "$duration_seconds" =~ ^[0-9]+$ ]]; then
    echo "unknown"
    return
  fi

  human_duration "$duration_seconds"
}

release_lock() {
  local lock_dir="$1"
  [[ -n "$lock_dir" ]] && rm -rf "$lock_dir"
}

remove_cleanup_path() {
  local target="$1"
  local updated=()
  local path

  for path in "${cleanup_paths[@]}"; do
    if [[ "$path" != "$target" && -n "$path" ]]; then
      updated+=( "$path" )
    fi
  done

  cleanup_paths=( "${updated[@]}" )
}

for i in "${!files[@]}"; do
  input_file="${files[$i]}"
  [[ -f "$input_file" ]] || continue

  base_name="$(basename "$input_file")"
  stem="${base_name%.*}"
  transcript_path="$input_dir/$stem.txt"
  lock_dir="$input_dir/$stem.whisper-lock"

  if [[ -f "$transcript_path" ]]; then
    echo "Skipping $base_name because $stem.txt already exists"
    skipped=$((skipped + 1))
    continue
  fi
  pending_base_names+=( "$base_name" )
  pending_lock_dirs+=( "$lock_dir" )
  pending_display_indexes+=( "$((i + 1))" )
  pending_duration_labels+=( "$(get_media_duration_label "$base_name")" )
done

cleanup() {
  local path
  for path in "${cleanup_paths[@]}"; do
    release_lock "$path"
  done
}

trap cleanup EXIT

if [[ ${#pending_base_names[@]} -eq 0 ]]; then
  script_finished_epoch="$(date +%s)"
  script_finished_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
  total_elapsed=$((script_finished_epoch - script_started_epoch))
  total_duration="$(human_duration "$total_elapsed")"
  echo "Script finished at: $script_finished_at"
  echo "Done. Processed: $processed, skipped: $skipped, total runtime: $total_duration"
  exit 0
fi

start_job() {
  local queue_index="$1"
  local base_name="${pending_base_names[$queue_index]}"
  local lock_dir="${pending_lock_dirs[$queue_index]}"
  local display_index="${pending_display_indexes[$queue_index]}"
  local duration_label="${pending_duration_labels[$queue_index]}"
  local result_file

  if [[ -d "$lock_dir" ]]; then
    echo "Skipping $base_name because lock exists: $lock_dir"
    skipped=$((skipped + 1))
    return
  fi

  if ! mkdir "$lock_dir" 2>/dev/null; then
    echo "Skipping $base_name because lock exists: $lock_dir"
    skipped=$((skipped + 1))
    return
  fi

  cleanup_paths+=( "$lock_dir" )
  result_file="$(mktemp)"
  file_started_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "[$display_index/${#files[@]}] Starting $base_name at $file_started_at (duration $duration_label)"

  (
    file_started_at="${SECONDS}"
    whisper_args=(whisper "/app/$base_name" --model "$model" --output_dir /app --output_format "$output_format")
    if [[ -n "$language" ]]; then
      whisper_args+=(--language "$language")
    fi

    if docker run --rm \
      -v "$model_cache_dir:/root/.cache/whisper" \
      -v "$input_dir:/app" \
      "$image_name" "${whisper_args[@]}"; then
      exit_code=0
    else
      exit_code=$?
    fi

    file_elapsed=$((SECONDS - file_started_at))
    release_lock "$lock_dir"

    {
      printf '%s\n' "$base_name"
      printf '%s\n' "$file_elapsed"
      printf '%s\n' "$exit_code"
      printf '%s\n' "$lock_dir"
    } > "$result_file"
  ) &

  active_pids+=( "$!" )
  active_result_files+=( "$result_file" )
}

reap_one_job() {
  local idx pid result_file base_name file_elapsed exit_code lock_dir
  local result_line_1 result_line_2 result_line_3 result_line_4

  while true; do
    for idx in "${!active_pids[@]}"; do
      pid="${active_pids[$idx]}"
      if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" || true
        result_file="${active_result_files[$idx]}"

        IFS= read -r result_line_1 < "$result_file"
        IFS= read -r result_line_2 < <(sed -n '2p' "$result_file")
        IFS= read -r result_line_3 < <(sed -n '3p' "$result_file")
        IFS= read -r result_line_4 < <(sed -n '4p' "$result_file")
        rm -f "$result_file"

        base_name="$result_line_1"
        file_elapsed="$result_line_2"
        exit_code="$result_line_3"
        lock_dir="$result_line_4"

        release_lock "$lock_dir"
        remove_cleanup_path "$lock_dir"

        if [[ "$exit_code" == "0" ]]; then
          echo "Finished $base_name in $(human_duration "$file_elapsed")"
          processed=$((processed + 1))
        else
          echo "Failed $base_name with exit code $exit_code" >&2
          failed=$((failed + 1))
        fi

        unset 'active_pids[idx]'
        unset 'active_result_files[idx]'
        active_pids=( "${active_pids[@]}" )
        active_result_files=( "${active_result_files[@]}" )
        return
      fi
    done

    sleep 1
  done
}

queue_index=0
while [[ $queue_index -lt ${#pending_base_names[@]} || ${#active_pids[@]} -gt 0 ]]; do
  while [[ $queue_index -lt ${#pending_base_names[@]} && ${#active_pids[@]} -lt $max_parallel ]]; do
    start_job "$queue_index"
    queue_index=$((queue_index + 1))
  done

  if [[ ${#active_pids[@]} -gt 0 ]]; then
    reap_one_job
  fi
done

script_finished_epoch="$(date +%s)"
script_finished_at="$(date '+%Y-%m-%d %H:%M:%S %z')"
total_elapsed=$((script_finished_epoch - script_started_epoch))
total_duration="$(human_duration "$total_elapsed")"
echo "Script finished at: $script_finished_at"
echo "Done. Processed: $processed, skipped: $skipped, total runtime: $total_duration"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
