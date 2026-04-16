$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$projectDir = $PSScriptRoot
$toolsDir = Join-Path $projectDir ".tools"
$videoDir = Join-Path $projectDir "gallery_video"

if (!(Test-Path $toolsDir)) { New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null }
if (!(Test-Path $videoDir)) { New-Item -ItemType Directory -Force -Path $videoDir | Out-Null }

Write-Host "Checking for tools..."

$ytDlpPath = Join-Path $toolsDir "yt-dlp.exe"
if (!(Test-Path $ytDlpPath)) {
    Write-Host "Downloading yt-dlp.exe..."
    Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile $ytDlpPath
}

$ffmpegPath = Join-Path $toolsDir "ffmpeg.exe"
if (!(Test-Path $ffmpegPath)) {
    Write-Host "Downloading FFmpeg..."
    # Download a tiny ffmpeg static build
    $ffmpegZip = Join-Path $toolsDir "ffmpeg.zip"
    Invoke-WebRequest -Uri "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile $ffmpegZip
    Write-Host "Extracting FFmpeg..."
    Expand-Archive -Path $ffmpegZip -DestinationPath $toolsDir -Force
    # Find the extracted ffmpeg.exe
    $extractedExe = Get-ChildItem -Path $toolsDir -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1
    Copy-Item -Path $extractedExe.FullName -Destination $ffmpegPath -Force
    Remove-Item $ffmpegZip -Force
}

$mp4File = Join-Path $videoDir "waterfall_raw.mp4"
$ogvFile = Join-Path $videoDir "waterfall_hd.ogv"

if (!(Test-Path $ogvFile)) {
    Write-Host "Downloading waterfall video from YouTube..."
    # -f "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" to keep it small and fast.
    # Search up to 5 videos and take the first one under 30 seconds
    & $ytDlpPath --match-filter "duration <= 30" -f "best[height<=720][ext=mp4]/best" --max-downloads 1 -o $mp4File "ytsearch5:waterfall nature 4k creative commons short"
    
    Write-Host "Converting video to .ogv for Godot (max 10 seconds)..."
    # Convert without audio first to ensure fast, safe silent canvas loops.
    # -c:v libtheora -q:v 7 -an
    & $ffmpegPath -y -i $mp4File -t 10 -c:v libtheora -q:v 7 -an $ogvFile
    
    if (Test-Path $ogvFile) {
        Write-Host "Godot .ogv video successfully created!"
        Remove-Item $mp4File -Force
    } else {
        Write-Error "Conversion failed."
    }
} else {
    Write-Host "OGV video already exists. Skipping download."
}
