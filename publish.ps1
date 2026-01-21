
$sourceDir = Join-Path $PSScriptRoot "src"

# Load path from .env
$envPath = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envPath)) {
    Write-Error ".env file not found at $envPath"
    exit 1
}

$env = @{}
Get-Content $envPath | Where-Object { $_ -match '=' -and -not ($_ -match '^\s*#') } | ForEach-Object {
    $parts = $_ -split '=', 2
    $env[$parts[0].Trim()] = $parts[1].Trim()
}

$destDir = $env["WOW_ADDON_PATH"]
if (-not $destDir) {
     Write-Error "WOW_ADDON_PATH not found in .env"
     exit 1
}

Write-Host "=============================="
Write-Host "   Publishing WhackAMole      "
Write-Host "=============================="
Write-Host "Source: $sourceDir"
Write-Host "Destination: $destDir"

if (-not (Test-Path $sourceDir)) {
    Write-Error "Source directory not found!"
    exit 1
}

# ȷ��Ŀ�길Ŀ¼����
$parentDir = Split-Path -Parent $destDir
if (-not (Test-Path $parentDir)) {
    Write-Host "Creating AddOns folder: $parentDir"
    New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
}

# �����ɰ汾
if (Test-Path $destDir) {
    Write-Host "Cleaning up old version..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $destDir
}

# �����ļ�
Write-Host "Copying files..." -ForegroundColor Cyan

# Create destination directory
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
}

# Copy all files from src
Get-ChildItem -Path $sourceDir | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $destDir -Recurse -Force
}

Write-Host "Done!" -ForegroundColor Green
