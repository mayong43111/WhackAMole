# Configuration
$ADDON_NAME = "WhackAMole"
$SRC_DIR = "src"
$BUILD_DIR = "dist"
$TOC_FILE = "$SRC_DIR\$ADDON_NAME.toc"

# Get Version
if (Test-Path $TOC_FILE) {
    $VERSION = (Get-Content $TOC_FILE | Where-Object { $_ -match "^## Version:" }) -replace "^## Version:\s*", ""
    # Replace spaces with underscores for filename safety
    $VERSION = $VERSION -replace " ", "_"
} else {
    $VERSION = "Unknown"
}

$ZIP_NAME = "${ADDON_NAME}_v${VERSION}.zip"

# Clean up
if (Test-Path $BUILD_DIR) {
    Write-Host "Cleaning up old build..."
    Remove-Item -Path $BUILD_DIR -Recurse -Force
}

# Create Build Structure
New-Item -Path "$BUILD_DIR\$ADDON_NAME" -ItemType Directory -Force | Out-Null

# Copy Files
Write-Host "Copying files..."
Copy-Item -Path "$SRC_DIR\*" -Destination "$BUILD_DIR\$ADDON_NAME\" -Recurse -Force

# Clean up unwanted files (e.g., .DS_Store)
Get-ChildItem -Path "$BUILD_DIR\$ADDON_NAME" -Filter ".DS_Store" -Recurse -Force | Remove-Item -Force

# Create Zip
Write-Host "Creating archive: $ZIP_NAME"
$zipPath = Join-Path (Get-Location) "$BUILD_DIR\$ZIP_NAME"
Compress-Archive -Path "$BUILD_DIR\$ADDON_NAME" -DestinationPath $zipPath -Force

if ($?) {
    Write-Host "========================================"
    Write-Host "Build Success!"
    Write-Host "File created at: $BUILD_DIR\$ZIP_NAME"
    Write-Host "========================================"
} else {
    Write-Host "Build Failed!"
    exit 1
}
