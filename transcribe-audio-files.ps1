$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputDir = Join-Path $scriptDir "audio-files"
$modelCacheDir = Join-Path $scriptDir "models"
$imageName = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "openai-whisper" }
$model = if ($env:MODEL) { $env:MODEL } else { "small" }
$language = if ($env:LANGUAGE) { $env:LANGUAGE } else { "Russian" }
$outputFormat = if ($env:OUTPUT_FORMAT) { $env:OUTPUT_FORMAT } else { "txt" }

$supportedExtensions = @(
  ".mp3",
  ".m4a",
  ".wav",
  ".flac",
  ".ogg",
  ".mp4",
  ".mov",
  ".mkv",
  ".webm",
  ".aac",
  ".opus",
  ".wma",
  ".alac",
  ".3gp"
)

function Format-Hms {
  param([int]$TotalSeconds)

  $hours = [Math]::Floor($TotalSeconds / 3600)
  $minutes = [Math]::Floor(($TotalSeconds % 3600) / 60)
  $seconds = $TotalSeconds % 60
  return ("{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $seconds)
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "docker not found in PATH"
}

if (-not (Test-Path -LiteralPath $inputDir)) {
  throw "Input directory not found: $inputDir"
}

New-Item -ItemType Directory -Force -Path $modelCacheDir | Out-Null

$inputMount = ((Resolve-Path -LiteralPath $inputDir).Path -replace '\\', '/')
$modelMount = ((Resolve-Path -LiteralPath $modelCacheDir).Path -replace '\\', '/')

Write-Host "Input directory: $inputDir"
Write-Host "Model cache: $modelCacheDir"
Write-Host "Whisper model: $model"
Write-Host "Language: $language"
Write-Host "Output format: $outputFormat"

$imageExists = $true
try {
  & docker image inspect $imageName 1>$null 2>$null
  $imageExists = ($LASTEXITCODE -eq 0)
}
catch {
  $imageExists = $false
}

if (-not $imageExists) {
  Write-Host "Building Docker image: $imageName"
  & docker build -t $imageName $scriptDir
  if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed with exit code $LASTEXITCODE"
  }
}

$files = Get-ChildItem -LiteralPath $inputDir -File |
  Where-Object { $supportedExtensions -contains $_.Extension.ToLowerInvariant() } |
  Sort-Object Name

if ($files.Count -eq 0) {
  Write-Host "No supported audio/video files found in: $inputDir"
  exit 0
}

$processed = 0
$skipped = 0
$startedAt = Get-Date

foreach ($inputFile in $files) {
  $baseName = $inputFile.Name
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
  $transcriptPath = Join-Path $inputDir ($stem + ".txt")

  if (Test-Path -LiteralPath $transcriptPath) {
    Write-Host "Skipping $baseName because $stem.txt already exists"
    $skipped++
    continue
  }

  $fileStartedAt = Get-Date
  Write-Host ("[{0}/{1}] Transcribing {2}" -f ($processed + $skipped + 1), $files.Count, $baseName)

  $dockerArgs = @(
    "run",
    "--rm",
    "-v", "${modelMount}:/root/.cache/whisper",
    "-v", "${inputMount}:/app",
    $imageName,
    "whisper",
    "/app/$baseName",
    "--model", $model,
    "--output_dir", "/app",
    "--output_format", $outputFormat,
    "--language", $language
  )

  & docker @dockerArgs
  if ($LASTEXITCODE -ne 0) {
    throw "Transcription failed for '$baseName' with exit code $LASTEXITCODE"
  }

  $elapsed = (Get-Date) - $fileStartedAt
  Write-Host ("Finished {0} in {1}" -f $baseName, (Format-Hms -TotalSeconds [int]$elapsed.TotalSeconds))
  $processed++
}

$totalElapsed = (Get-Date) - $startedAt
Write-Host ("Done. Processed: {0}, skipped: {1}, total time: {2}" -f $processed, $skipped, (Format-Hms -TotalSeconds [int]$totalElapsed.TotalSeconds))
