param (
    [string]$url,
    [switch]$AudioOnly,
    [int]$Quality,
    [switch]$Subtitles,
    [switch]$SubtitleOnly,
    [switch]$Help
)

# === Show help if -Help ===
if ($Help) {
    Write-Host @"

yt-dlp Wrapper for PowerShell (v.1.0.0)
---------------------------------------
Download audio/video/subtitles using yt-dlp + ffmpeg tools.

Usage:
  ytdlp.ps1 <url> [options]

Options:
  -AudioOnly         Download best audio as MP3
  -Quality <number>  Max resolution (e.g., 720)
  -Subtitles         Download subtitles (with video)
  -SubtitleOnly      Download only subtitles (no video/audio)
  -Help              Show this help message

Examples:
  ytdlp.ps1 https://youtube.com/watch?v=abc123
  ytdlp.ps1 https://youtube.com/watch?v=abc123 -AudioOnly
  ytdlp.ps1 https://youtube.com/watch?v=abc123 -Quality 720 -Subtitles
  ytdlp.ps1 https://youtube.com/watch?v=abc123 -SubtitleOnly

Powered by yt-dlp + ffmpeg
"@
    exit 0
}

# === Ask for URL if not provided ===
if (-not $url) {
    $url = Read-Host "Please enter the URL to download"
    if (-not $url) {
        Write-Host "No URL provided. Exiting." -ForegroundColor Red
        exit 1
    }
}

# === Setup paths ===
$ytDlpFolder = "$HOME\Documents\PowerShell\Library\ytdlp"
$ytDlpPath = Join-Path $ytDlpFolder "yt-dlp.exe"
$ffmpegPath = Join-Path $ytDlpFolder "ffmpeg.exe"

# === Create tool folder if missing ===
if (-not (Test-Path $ytDlpFolder)) {
    New-Item -ItemType Directory -Path $ytDlpFolder -Force | Out-Null
}

# === Check yt-dlp ===
if (-not (Test-Path $ytDlpPath)) {
    Write-Host "yt-dlp.exe not found in $ytDlpFolder" -ForegroundColor Red
    $confirm = Read-Host "Do you want to download yt-dlp.exe now? (Y/N)"
    if ($confirm -match '^[Yy]$') {
        Write-Host "Downloading yt-dlp.exe..." -ForegroundColor Cyan
        curl.exe -L `
        "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" `
        -o $ytDlpPath

        if (-not (Test-Path $ytDlpPath)) {
            Write-Error "yt-dlp download failed."
            exit 1
        }
    } else {
        Write-Host "Download cancelled. Exiting." -ForegroundColor Yellow
        exit 1
    }
}

# === Check ffmpeg ===
if (-not (Test-Path $ffmpegPath)) {
    Write-Host "ffmpeg.exe not found in $ytDlpFolder" -ForegroundColor Red
    $confirmFFMPEG = Read-Host "Do you want to download ffmpeg.exe now? (Y/N)"
    if ($confirmFFMPEG -match '^[Yy]$') {
        $tempZip = "$env:TEMP\ffmpeg.zip"
        $tempDir = "$env:TEMP\ffmpeg_extracted"

        try {
            Write-Host "Downloading ffmpeg..."
            Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $tempZip
            Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
            $ffmpegExtracted = Get-ChildItem -Recurse -Path $tempDir -Filter "ffmpeg.exe" | Select-Object -First 1
            if ($ffmpegExtracted) {
                Copy-Item $ffmpegExtracted.FullName -Destination $ffmpegPath -Force
                Write-Host "ffmpeg.exe copied to: $ffmpegPath" -ForegroundColor Green
            } else {
                Write-Error "ffmpeg.exe not found in archive!"
                exit 1
            }

            Remove-Item $tempZip -Force
            Remove-Item $tempDir -Recurse -Force
        } catch {
            Write-Error "Failed to install ffmpeg: $_"
            exit 1
        }
    } else {
        Write-Warning "ffmpeg is required for merging and mp3 conversion. Some features may not work."
    }
}

# === Build yt-dlp command ===
$args = @()

# Force yt-dlp to use local ffmpeg if present
$args += "--ffmpeg-location"; $args += $ytDlpFolder

# Set output format for subtitles
if ($SubtitleOnly -or $Subtitles) {
    $args += "--output"; $args += "%(title)s/%(title)s.%(language)s.%(ext)s"
}

# Subtitle only
if ($SubtitleOnly) {
    $args += "--skip-download"
    $args += "--all-subs"
    $args += "--write-sub"
    $args += "--convert-subs"; $args += "srt"
    Write-Host "Downloading manual subtitles only..." -ForegroundColor Cyan
}
# Audio only
elseif ($AudioOnly) {
    $args += "--extract-audio"
    $args += "--audio-format"; $args += "mp3"
    $args += "--audio-quality"; $args += "0"
    Write-Host "Downloading best audio only (MP3)..." -ForegroundColor Cyan
}
# Video
else {
    if ($Quality) {
        $formatSelector = "bestvideo[height<=$Quality]+bestaudio/best"
        Write-Host "Downloading video up to ${Quality}p (fallback to best lower)..." -ForegroundColor Cyan
    } else {
        $formatSelector = "bestvideo+bestaudio"
        Write-Host "Downloading best available video + audio..." -ForegroundColor Cyan
    }
    $args += "-f"; $args += $formatSelector
    $args += "--merge-output-format"; $args += "mp4"
}

# Subtitles with video/audio
if (-not $SubtitleOnly -and $Subtitles) {
    $args += "--all-subs"
    $args += "--write-sub"
    $args += "--convert-subs"; $args += "srt"
    Write-Host "Downloading manual subtitles with video/audio..." -ForegroundColor Cyan
}

# Add URL last
$args += $url

# === Run yt-dlp ===
& $ytDlpPath @args
