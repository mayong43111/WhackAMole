#!/bin/bash

# Configuration
ADDON_NAME="WhackAMole"
SRC_DIR="src"
BUILD_DIR="dist"
TOC_FILE="${SRC_DIR}/${ADDON_NAME}.toc"

# Get Version
if [ -f "$TOC_FILE" ]; then
    VERSION=$(grep "^## Version:" "$TOC_FILE" | cut -d: -f2 | xargs)
    # Replace spaces with underscores for filename safety
    VERSION=${VERSION// /_}
else
    VERSION="Unknown"
fi

ZIP_NAME="${ADDON_NAME}_v${VERSION}.zip"

# Clean up
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning up old build..."
    rm -rf "$BUILD_DIR"
fi

# Create Build Structure
mkdir -p "${BUILD_DIR}/${ADDON_NAME}"

# Copy Files
echo "Copying files..."
cp -r "${SRC_DIR}/"* "${BUILD_DIR}/${ADDON_NAME}/"

# Clean up unwanted files (e.g., .DS_Store, verify Logic/APL files)
find "${BUILD_DIR}/${ADDON_NAME}" -name ".DS_Store" -delete
# If specific developer files shouldn't be shipped, remove them here.
# For now, we assume src/ contains only shipping code.

# Create Zip
echo "creating archive: ${ZIP_NAME}"
cd "${BUILD_DIR}"
zip -r "${ZIP_NAME}" "${ADDON_NAME}"

if [ $? -eq 0 ]; then
    echo "========================================"
    echo "Build Success!"
    echo "File created at: ${BUILD_DIR}/${ZIP_NAME}"
    echo "========================================"
else
    echo "Build Failed!"
    exit 1
fi
