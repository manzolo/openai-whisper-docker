$ErrorActionPreference = "Stop"

$scriptStartedAt = Get-Date

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputDir = Join-Path $scriptDir "audio-files"
$modelCacheDir = Join-Path $scriptDir "models"
$defaultMaxParallel = 2
$imageName = if ($env:IMAGE_NAME) { $env:IMAGE_NAME } else { "openai-whisper" }
$model = if ($env:MODEL) { $env:MODEL } else { "small" }
$language = if ($env:LANGUAGE) { $env:LANGUAGE } else { "Russian" }
$outputFormat = if ($env:OUTPUT_FORMAT) { $env:OUTPUT_FORMAT } else { "txt" }
$maxParallelRaw = if ($env:MAX_PARALLEL) { $env:MAX_PARALLEL } else { $defaultMaxParallel.ToString() }

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

  $hours = [int][Math]::Floor($TotalSeconds / 3600)
  $minutes = [int][Math]::Floor(($TotalSeconds % 3600) / 60)
  $seconds = [int]($TotalSeconds % 60)
  return ("{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $seconds)
}

function Format-Timestamp {
  param([datetime]$DateTime)

  return $DateTime.ToString("yyyy-MM-dd HH:mm:ss zzz")
}

function Get-MediaDurationLabel {
  param(
    [string]$ImageName,
    [string]$InputMount,
    [string]$BaseName
  )

  $ffprobeArgs = @(
    "run",
    "--rm",
    "-v", "${InputMount}:/app",
    $ImageName,
    "ffprobe",
    "-v", "error",
    "-show_entries", "format=duration",
    "-of", "default=noprint_wrappers=1:nokey=1",
    "/app/$BaseName"
  )

  try {
    $durationOutput = (& docker @ffprobeArgs 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($durationOutput)) {
      return "unknown"
    }

    $durationSeconds = 0.0
    if (-not [double]::TryParse($durationOutput, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$durationSeconds)) {
      return "unknown"
    }

    return (Format-Hms -TotalSeconds ([int][Math]::Round($durationSeconds)))
  }
  catch {
    return "unknown"
  }
}

function Remove-LockDirectory {
  param([string]$LockPath)

  if (Test-Path -LiteralPath $LockPath) {
    Remove-Item -LiteralPath $LockPath -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$maxParallel = 0
if (-not [int]::TryParse($maxParallelRaw, [ref]$maxParallel) -or $maxParallel -lt 1) {
  throw "MAX_PARALLEL must be a positive integer"
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
Write-Host "Max parallel jobs: $maxParallel"
Write-Host ("Script started at: {0}" -f (Format-Timestamp -DateTime $scriptStartedAt))

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

$files = @(Get-ChildItem -LiteralPath $inputDir -File |
  Where-Object { $supportedExtensions -contains $_.Extension.ToLowerInvariant() } |
  Sort-Object Name)

if ($files.Count -eq 0) {
  Write-Host "No supported audio/video files found in: $inputDir"
  $scriptFinishedAt = Get-Date
  $totalElapsed = $scriptFinishedAt - $scriptStartedAt
  $totalElapsedSeconds = [int][Math]::Round($totalElapsed.TotalSeconds)
  Write-Host ("Script finished at: {0}" -f (Format-Timestamp -DateTime $scriptFinishedAt))
  Write-Host ("Done. Processed: {0}, skipped: {1}, total runtime: {2}" -f 0, 0, (Format-Hms -TotalSeconds $totalElapsedSeconds))
  exit 0
}

$processed = 0
$skipped = 0
$failed = @()
$queue = [System.Collections.Queue]::new()
$activeJobs = @()

for ($i = 0; $i -lt $files.Count; $i++) {
  $inputFile = $files[$i]
  $baseName = $inputFile.Name
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
  $transcriptPath = Join-Path $inputDir ($stem + ".txt")
  $lockPath = Join-Path $inputDir ($stem + ".whisper-lock")

  if (Test-Path -LiteralPath $transcriptPath) {
    Write-Host "Skipping $baseName because $stem.txt already exists"
    $skipped++
    continue
  }

  $queue.Enqueue([pscustomobject]@{
      Index         = $i + 1
      BaseName      = $baseName
      LockPath      = $lockPath
      DurationLabel = (Get-MediaDurationLabel -ImageName $imageName -InputMount $inputMount -BaseName $baseName)
    })
}

if ($queue.Count -eq 0) {
  $scriptFinishedAt = Get-Date
  $totalElapsed = $scriptFinishedAt - $scriptStartedAt
  $totalElapsedSeconds = [int][Math]::Round($totalElapsed.TotalSeconds)
  Write-Host ("Script finished at: {0}" -f (Format-Timestamp -DateTime $scriptFinishedAt))
  Write-Host ("Done. Processed: {0}, skipped: {1}, total runtime: {2}" -f $processed, $skipped, (Format-Hms -TotalSeconds $totalElapsedSeconds))
  exit 0
}

$jobScript = {
  param(
    [string]$ImageName,
    [string]$ModelMount,
    [string]$InputMount,
    [string]$BaseName,
    [string]$Model,
    [string]$OutputFormat,
    [string]$Language,
    [string]$LockPath
  )

  $ErrorActionPreference = "Continue"
  $PSNativeCommandUseErrorActionPreference = $false
  $fileStartedAt = Get-Date
  $dockerArgs = @(
    "run",
    "--rm",
    "-v", "${ModelMount}:/root/.cache/whisper",
    "-v", "${InputMount}:/app",
    $ImageName,
    "whisper",
    "/app/$BaseName",
    "--model", $Model,
    "--output_dir", "/app",
    "--output_format", $OutputFormat
  )

  if (-not [string]::IsNullOrWhiteSpace($Language)) {
    $dockerArgs += @("--language", $Language)
  }

  try {
    & docker @dockerArgs *> $null
    $exitCode = $LASTEXITCODE
    $elapsed = (Get-Date) - $fileStartedAt
    [pscustomobject]@{
      BaseName       = $BaseName
      ExitCode       = $exitCode
      ElapsedSeconds = [int][Math]::Round($elapsed.TotalSeconds)
      Success        = ($exitCode -eq 0)
      ErrorMessage   = $null
      LockPath       = $LockPath
    }
  }
  catch {
    $elapsed = (Get-Date) - $fileStartedAt
    [pscustomobject]@{
      BaseName       = $BaseName
      ExitCode       = -1
      ElapsedSeconds = [int][Math]::Round($elapsed.TotalSeconds)
      Success        = $false
      ErrorMessage   = $_.Exception.Message
      LockPath       = $LockPath
    }
  }
}

while ($queue.Count -gt 0 -or $activeJobs.Count -gt 0) {
  while ($queue.Count -gt 0 -and $activeJobs.Count -lt $maxParallel) {
    $item = $queue.Dequeue()

    if (Test-Path -LiteralPath $item.LockPath) {
      Write-Host "Skipping $($item.BaseName) because lock exists: $($item.LockPath)"
      $skipped++
      continue
    }

    try {
      New-Item -ItemType Directory -Path $item.LockPath -ErrorAction Stop | Out-Null
    }
    catch {
      Write-Host "Skipping $($item.BaseName) because lock exists: $($item.LockPath)"
      $skipped++
      continue
    }

    $fileStartedAt = Get-Date
    Write-Host ("[{0}/{1}] Starting {2} at {3} (duration {4})" -f $item.Index, $files.Count, $item.BaseName, (Format-Timestamp -DateTime $fileStartedAt), $item.DurationLabel)

    $job = Start-Job -ScriptBlock $jobScript -ArgumentList @(
      $imageName,
      $modelMount,
      $inputMount,
      $item.BaseName,
      $model,
      $outputFormat,
      $language,
      $item.LockPath
    )

    $activeJobs += [pscustomobject]@{
      BaseName = $item.BaseName
      LockPath = $item.LockPath
      Job      = $job
    }
  }

  $readyJob = Wait-Job -Job ($activeJobs.Job) -Any
  $jobInfo = $activeJobs | Where-Object { $_.Job.Id -eq $readyJob.Id } | Select-Object -First 1
  $result = Receive-Job -Job $readyJob
  Remove-Job -Job $readyJob
  Remove-LockDirectory -LockPath $jobInfo.LockPath
  $activeJobs = @($activeJobs | Where-Object { $_.Job.Id -ne $readyJob.Id })

  if ($result.Success) {
    Write-Host ("Finished {0} in {1}" -f $result.BaseName, (Format-Hms -TotalSeconds $result.ElapsedSeconds))
    $processed++
    continue
  }

  $errorMessage = if ($result.ErrorMessage) { $result.ErrorMessage } else { "docker exited with code $($result.ExitCode)" }
  Write-Host ("Failed {0}: {1}" -f $result.BaseName, $errorMessage)
  $failed += $result
}

$scriptFinishedAt = Get-Date
$totalElapsed = $scriptFinishedAt - $scriptStartedAt
$totalElapsedSeconds = [int][Math]::Round($totalElapsed.TotalSeconds)
Write-Host ("Script finished at: {0}" -f (Format-Timestamp -DateTime $scriptFinishedAt))
Write-Host ("Done. Processed: {0}, skipped: {1}, total runtime: {2}" -f $processed, $skipped, (Format-Hms -TotalSeconds $totalElapsedSeconds))

if ($failed.Count -gt 0) {
  $failedNames = ($failed | ForEach-Object { $_.BaseName }) -join ", "
  throw "Transcription failed for: $failedNames"
}
